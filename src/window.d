module window;

import core.stdc.stdio;
import sdl3;

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

		// TODO: Extract to Renderer:
		_rdrP = SDL_CreateRenderer(_winP, null);
		if (_rdrP is null) {
			stderr.fprintf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
			SDL_DestroyWindow(_winP);
			SDL_Quit();
			return;
		}
		if (!SDL_SetRenderVSync(_rdrP, 1))
			stderr.fprintf("Warning: VSync not supported\n");

	}
	~this() nothrow @nogc @trusted {
		SDL_DestroyRenderer(_rdrP);
		SDL_DestroyWindow(_winP);
	}
	ScreenSize size() @property @trusted {
		typeof(return) ssz;
		SDL_GetWindowSize(_winP, &ssz.width, &ssz.height);
		return ssz;
	}
	SDL_Window* _winP;
	SDL_Renderer* _rdrP;
}
