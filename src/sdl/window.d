module sdl.window;

import sdl;

@safe:

alias DisplayMode = SDL_DisplayMode;

struct Window {
	alias Flags = SDL_WindowFlags;

	@disable this(this);

	this(in ScreenSize ssz, in char[] title, Flags flags = 0) @trusted {
		SDL_Window *ptrW;
		SDL_Renderer *ptrR;
		if (!SDL_CreateWindowAndRenderer(title.ptr, ssz.width, ssz.height, cast(uint)flags,
										&ptrW, &ptrR)) {
			warningf("Couldn't create window and renderer, %s", SDL_GetError().fromStringz);
			SDL_Quit();
			return;
		}
		_ptr = ptrW;
		rdr = Renderer(ptrR);
		fullscreen = true;
	}

	~this() @trusted @il /+ nothrow @nogc +/
		=> SDL_DestroyWindow(_ptr);

	ScreenSize size() const scope nothrow @nogc @property @trusted @il  {
		typeof(return) ssz;
		SDL_GetWindowSize((cast()this)._ptr, &ssz.width, &ssz.height);
		return ssz;
	}

	bool fullscreen() const scope nothrow @nogc @property @il
		=> inFullscreen;

	void fullscreen(in bool fullscreen_) scope @property @trusted @il {
		if (!SDL_SetWindowFullscreen((cast()this)._ptr, fullscreen_))
			warning("Couldn't set fullscreen state of %s to %s, %s", _ptr, fullscreen_, SDL_GetError());
		inFullscreen = fullscreen_;
	}

	DisplayMode* fullscreenMode() scope @property @trusted @il
		=> SDL_GetWindowFullscreenMode((cast()this)._ptr);

	Flags flags() const scope @property @trusted @il
		=> SDL_GetWindowFlags((cast()this)._ptr);

	Renderer rdr;
	package SDL_Window* _ptr;
	invariant(_ptr);
	/+ TODO: Remove in favor of state handling via
	   `SDL_SetWindowFullscreenMode` and
	   `SDL_GetWindowFullscreenMode`:
	 +/
	bool inFullscreen;
}

extern(C) {
}
