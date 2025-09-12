module renderer;

import core.stdc.stdio;
import window;
import sdl3;

@safe:

struct Renderer {
	@disable this(this);
	this(scope ref Window win, immutable char* name = null) @trusted {
		_rdrP = SDL_CreateRenderer(win._winP, name);
		if (_rdrP is null) {
			stderr.fprintf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
			SDL_DestroyWindow(win._winP);
			SDL_Quit();
			return;
		}
		if (!SDL_SetRenderVSync(_rdrP, 1))
			stderr.fprintf("Warning: VSync not supported\n");
	}
	~this() nothrow @nogc @trusted {
		SDL_DestroyRenderer(_rdrP);
	}
	SDL_Renderer* _rdrP;
}
