module window;

import core.stdc.stdio;
import sdl3;
import renderer;

@safe:

struct Window {
	@disable this(this);
	this(in ScreenSize ssz, in char* title, bool fullscreen = false) @trusted {
		uint flags = SDL_WINDOW_RESIZABLE;

		/+ if (fullscreen) +/
		/+	flags |= SDL_WINDOW_FULLSCREEN_DESKTOP; +/
		_winP = SDL_CreateWindow(title, ssz.width, ssz.height, flags);
		if (fullscreen)
			SDL_SetWindowFullscreen(_winP, true);

		if (_winP is null) {
			stderr.fprintf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
			SDL_Quit();
			return;
		}
		rdr = Renderer(this);
	}
	~this() nothrow @nogc @trusted {
		SDL_DestroyWindow(_winP);
	}
	ScreenSize size() @property @trusted {
		typeof(return) ssz;
		SDL_GetWindowSize(_winP, &ssz.width, &ssz.height);
		return ssz;
	}
	SDL_Window* _winP;
	Renderer rdr;
}
