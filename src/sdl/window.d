module sdl.window;

import base;

@safe:

alias DisplayMode = SDL_DisplayMode;

nothrow struct Window {
	alias Flags = SDL_WindowFlags;
	@disable this(this);
	this(in ScreenSize ssz, in char[] title, Flags flags = 0) @trusted {
		const fullscreen = true;
		/+ if (fullscreen) +/
		/+	flags |= SDL_WINDOW_FULLSCREEN_DESKTOP; +/
		_ptr = SDL_CreateWindow(title.ptr, ssz.width, ssz.height, cast(uint)flags);
		if (fullscreen)
			SDL_SetWindowFullscreen(_ptr, true);
		if (_ptr is null) {
			warningf("Couldn't create window, %s", SDL_GetError().fromStringz);
			SDL_Quit();
			return;
		}
		rdr = Renderer(this);
	}
	~this() nothrow @nogc @trusted => SDL_DestroyWindow(_ptr);
	ScreenSize size() const scope @property @trusted {
		typeof(return) ssz;
		SDL_GetWindowSize((cast()this)._ptr, &ssz.width, &ssz.height);
		return ssz;
	}
	void fullscreen(in bool fullscreen = true) scope @property @trusted	{
		if (!SDL_SetWindowFullscreen((cast()this)._ptr, fullscreen))
			warning("Couldn't set fullscreen state of %s to %s, %s", _ptr, fullscreen, SDL_GetError());
	}
	DisplayMode* fullscreenMode() scope @property @trusted
		=> SDL_GetWindowFullscreenMode((cast()this)._ptr);
	Flags flags() const scope @property @trusted => SDL_GetWindowFlags((cast()this)._ptr);
	Renderer rdr;
	package SDL_Window* _ptr;
	invariant(_ptr);
}
