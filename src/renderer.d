module renderer;

import core.stdc.stdio;
import std.string : fromStringz;
import nxt.logger;
import nxt.effects;
import window;
import sdl;

@safe:

nothrow struct Renderer {
	@disable this(this);
	this(scope ref Window win, immutable char[] name = null) @trusted {
		_ptr = SDL_CreateRenderer(win._ptr, name.ptr);
		if (_ptr is null) {
			warningf("Renderer could not be created! SDL_Error: %s", SDL_GetError.fromStringz());
			SDL_Quit();
		}
		if (!SDL_SetRenderVSync(_ptr, 1))
			warning("VSync not supported");
	}
	~this() @nogc @trusted {
		SDL_DestroyRenderer(_ptr);
	}
	int setDrawColor(in RGBA color) nothrow @trusted @il
		=> SDL_SetRenderDrawColor(_ptr, color.r, color.g, color.b, color.a);
	int fillRect(in SDL_FRect frect) nothrow @trusted @il
		=> SDL_RenderFillRect(_ptr, &frect);
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
