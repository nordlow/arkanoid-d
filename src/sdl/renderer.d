module sdl.renderer;

import std.string : fromStringz;
import nxt.lut;
import nxt.logger;
import nxt.effects;
import sdl;

@safe:

nothrow struct Renderer {
	import std.math : sin, cos, PI;

	@disable this(this);

	this(scope ref Window win, immutable char[] name = null) @trusted {
		_ptr = SDL_CreateRenderer(win._ptr, name.ptr);
		if (_ptr is null) {
			warningf("Renderer could not be created! SDL_Error: %s", SDL_GetError.fromStringz());
			SDL_Quit();
		}
		if (!SDL_SetRenderVSync(_ptr, 1))
			warning("VSync not supported");
		_sincos = SinCos(0, 2*PI);
		_sincos.fill();
	}

	~this() @nogc @trusted @il
		=> SDL_DestroyRenderer(_ptr);

	int setDrawColor(in RGBA color) nothrow @trusted @il
		=> SDL_SetRenderDrawColor(_ptr, color.r, color.g, color.b, color.a);

	int fillRect(in SDL_FRect frect) nothrow @trusted @il
		=> SDL_RenderFillRect(_ptr, &frect);

	SDL_Renderer* _ptr;
	enum vertexCount = 32;
	alias SinCos = CyclicLookupTable!(float, vertexCount, sin, cos);
	SinCos _sincos;
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
