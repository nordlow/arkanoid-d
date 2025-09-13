module renderer;

import core.stdc.stdio;
import nxt.logger;
import window;
import sdl;

@safe:

nothrow struct Renderer {
	@disable this(this);
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

void drawFilledCircle(scope ref Renderer rdr, int centerX, int centerY, int radius) nothrow @trusted {
	for (auto y = -radius; y <= radius; y++) {
		for (auto x = -radius; x <= radius; x++) {
			if (x*x + y*y <= radius*radius) {
				const rect = SDL_FRect(centerX + x, centerY + y, 1, 1);
				SDL_RenderFillRect(rdr._ptr, &rect);
			}
		}
	}
}
