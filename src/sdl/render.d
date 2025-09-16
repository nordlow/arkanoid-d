module sdl.render;

import std.string : fromStringz;
import nxt.lut;
import nxt.logger;
import nxt.effects;
import sdl;

@safe:

struct Renderer { nothrow:
	import std.math : sin, cos, PI;
nothrow @nogc @il:
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

	private void initTabs() scope pure {
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

	/++ Clear the current rendering target with the current drawing color set
		with `setDrawColor`. +/
	bool clear() @trusted {
		const ret = SDL_RenderClear(_ptr);
		if (!ret)
			warningf("Couldn't clear, %s", SDL_GetError.fromStringz());
		return ret;
	}

	/++ Get the drawing color. +/
	RGBA getDrawColor() @trusted @property	{
		typeof(return) ret;
		if (!SDL_GetRenderDrawColor(_ptr, &ret.r, &ret.g, &ret.b, &ret.a))
			warningf("Couldn't get current drawing, %s", SDL_GetError.fromStringz());
		return ret;
	}

	/++ Set the drawing color. +/
	int setDrawColor(in RGBA color) @trusted @property
		=> SDL_SetRenderDrawColor(_ptr, color.r, color.g, color.b, color.a);

	int fillRect(in SDL_FRect frect) @trusted
		=> SDL_RenderFillRect(_ptr, &frect);

	bool renderGeometry(in Vertex *vertices, in int num_vertices) @trusted {
		const ret = SDL_RenderGeometry(_ptr, texture: null, cast(SDL_Vertex*)vertices, num_vertices, indices: cast(int*)null, num_indices: 0);
		if (!ret)
			warningf("Couldn't render geometry, %s", SDL_GetError.fromStringz());
		return ret;
	}

	bool present() @trusted {
		const ret = SDL_RenderPresent(_ptr);
		if (!ret)
			warningf("Couldn't present, %s", SDL_GetError.fromStringz());
		return ret;
	}

	SDL_Renderer* _ptr;
	enum vertexCount = 32;
	alias SinCos = CyclicLookupTable!(float, vertexCount, sin, cos);
	SinCos _sincos;
	invariant(_ptr);
}

alias Vertex = SDL_Vertex;
