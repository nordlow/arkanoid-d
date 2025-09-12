module renderer;

import core.stdc.stdio;
import window;
import sdl3;

@safe:

struct Renderer {
	@disable this(this);
nothrow:
	this(scope ref Window win, immutable char* name = null) @trusted {
		_ptr = SDL_CreateRenderer(win._ptr, name);
		if (_ptr is null) {
			stderr.fprintf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
			SDL_DestroyWindow(win._ptr);
			SDL_Quit();
			return;
		}
		if (!SDL_SetRenderVSync(_ptr, 1))
			stderr.fprintf("Warning: VSync not supported\n");
	}
	~this() @nogc @trusted {
		SDL_DestroyRenderer(_ptr);
	}
	SDL_Renderer* _ptr;
	invariant(_ptr);
}
