module window;

import core.stdc.stdio;
import sdl3;

@safe:

struct Window {
	@disable this(this);
	this(in ScreenSize ssz, in char* title = "Arkanoid Clone") @trusted {
		_win = SDL_CreateWindow(title, ssz.width, ssz.height, SDL_WINDOW_RESIZABLE);
		if (_win is null) {
			stderr.fprintf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
			SDL_Quit();
			return;
		}
		// TODO: Extract to Renderer:
		_rndr = SDL_CreateRenderer(_win, null);
		if (_rndr is null) {
			stderr.fprintf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
			SDL_DestroyWindow(_win);
			SDL_Quit();
			return;
		}
		if (!SDL_SetRenderVSync(_rndr, 1))
			stderr.fprintf("Warning: VSync not supported\n");

	}
	~this() nothrow @nogc @trusted {
		SDL_DestroyRenderer(_rndr);
		SDL_DestroyWindow(_win);
	}
	ScreenSize size() @property @trusted {
		typeof(return) ssz;
		SDL_GetWindowSize(_win, &ssz.width, &ssz.height);
		return ssz;
	}
	SDL_Window* _win;
	SDL_Renderer* _rndr;
}
