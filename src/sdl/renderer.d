module sdl.renderer;

import std.string : fromStringz;
import nxt.lut;
import nxt.logger;
import nxt.effects;
import sdl;

@safe:

struct Renderer { nothrow:
	import std.math : sin, cos, PI;
@il:
	@disable this(this);

	this(scope ref Window win, immutable char[] name = null) @trusted {
		auto ptr = SDL_CreateRenderer(win._ptr, name.ptr);
		if (ptr is null) {
			warningf("Couldn't create renderer, %s", SDL_GetError.fromStringz());
			SDL_Quit();
		}
		this(ptr);
	}

	package this(scope ref SDL_Renderer* ptr) @trusted in(ptr) {
		_ptr = ptr;
		setVSync(1);
		initTabs();
	}

	private void initTabs() scope pure nothrow @nogc {
		_sincos = SinCos(0, 2*PI);
		_sincos.fill();
	}

	bool setVSync(in int vsync) @trusted {
		const ret = SDL_SetRenderVSync(_ptr, 1);
		if (!ret)
			warning("VSync not supported");
		return ret;
	}

	~this() @nogc @trusted
		=> SDL_DestroyRenderer(_ptr);

	int setDrawColor(in RGBA color) nothrow @nogc @trusted
		=> SDL_SetRenderDrawColor(_ptr, color.r, color.g, color.b, color.a);

	int fillRect(in SDL_FRect frect) nothrow @nogc @trusted
		=> SDL_RenderFillRect(_ptr, &frect);

	SDL_Renderer* _ptr;
	enum vertexCount = 32;
	alias SinCos = CyclicLookupTable!(float, vertexCount, sin, cos);
	SinCos _sincos;
	invariant(_ptr);
}
