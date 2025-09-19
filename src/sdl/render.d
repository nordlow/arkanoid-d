module sdl.render;

import std.string : fromStringz;
import base;
import nxt.lut;
import nxt.logger;
import nxt.effects;
import sdl;

@safe:

struct Renderer { nothrow:
	import std.math : sin, cos, PI;
nothrow @nogc:
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

	private void initTabs() scope pure @il {
		_sincos = SinCos(0, 2*PI);
		_sincos.fill();
	}

	bool setVSync(in int vsync) @trusted @il {
		const ret = SDL_SetRenderVSync(_ptr, 1);
		if (!ret)
			warning("VSync not supported");
		return ret;
	}

	~this() @nogc @trusted @il
		=> SDL_DestroyRenderer(_ptr);

	/++ Clear the current rendering target with the current drawing color set
		with `setDrawColor`. +/
	bool clear() @trusted @il {
		const ret = SDL_RenderClear(_ptr);
		if (!ret)
			warningf("Couldn't clear, %s", SDL_GetError.fromStringz());
		return ret;
	}

	/++ Get the drawing color. +/
	RGBA drawColor() @trusted @property @il {
		typeof(return) ret;
		if (!SDL_GetRenderDrawColor(_ptr, &ret.r, &ret.g, &ret.b, &ret.a))
			warningf("Couldn't get the current drawing color, %s", SDL_GetError.fromStringz());
		return ret;
	}

	/++ Set the drawing color. +/
	void drawColor(in RGBA color) @trusted @property @il {
		if (!SDL_SetRenderDrawColor(_ptr, color.r, color.g, color.b, color.a))
			warningf("Couldn't set the current drawing color, %s", SDL_GetError.fromStringz());
	}

	int fillRect(in SDL_FRect frect) @trusted @il
		=> SDL_RenderFillRect(_ptr, &frect);

	void renderGeometry(in Vertex[] vertices) @trusted @il
		=> renderGeometry(vertices.ptr, cast(int)vertices.length);
	/// ditto
	package void renderGeometry(in Vertex *vertices, in int num_vertices) @trusted @il {
		const ret = SDL_RenderGeometry(_ptr, texture: null, cast(SDL_Vertex*)vertices, num_vertices, indices: cast(int*)null, num_indices: 0);
		if (!ret)
			warningf("Couldn't render geometry, %s", SDL_GetError.fromStringz());
	}

	void renderGeometry(in Vertex[] vertices, in int[] indices) @trusted @il
		=> renderGeometry(vertices.ptr, cast(int)vertices.length,
						  indices.ptr, cast(int)indices.length);
	/// ditto
	package void renderGeometry(in Vertex *vertices, in int num_vertices, in int *indices, int num_indices) @trusted @il {
		const ret = SDL_RenderGeometry(_ptr, texture: null, cast(SDL_Vertex*)vertices, num_vertices, indices: indices, num_indices: num_indices);
		if (!ret)
			warningf("Couldn't render geometry, %s", SDL_GetError.fromStringz());
	}

	bool present() @trusted @il {
		const ret = SDL_RenderPresent(_ptr);
		if (!ret)
			warningf("Couldn't present, %s", SDL_GetError.fromStringz());
		return ret;
	}

	SDL_Renderer* _ptr;
	enum nSinCos = 16;
	alias SinCos = CyclicLookupTable!(float, nSinCos, sin, cos);
	SinCos _sincos;
	invariant(_ptr);
}

/++ Tesselate `cir` to `verts`.
	TODO: Move to module `tesselation`.
	TODO: tigh this to `indicesCircleFan` somehow
 +/
void bakeCircleFan(scope ref Renderer rdr, in Cir cir, SDL_FColor fcolor, SDL_Vertex[] verts) pure nothrow @nogc {
	// center
	verts[0].position.x = cir.pos.x;
	verts[0].position.y = cir.pos.y;
	verts[0].color = fcolor;
	// circumference
	foreach (const int i; 0 .. Renderer.nSinCos) {
		const te = rdr._sincos[i]; // table entry
		const sin = te[0]; // sin
		const cos = te[1]; // cos
		verts[1 + i].position.x = cir.pos.x + cir.rad * cos;
		verts[1 + i].position.y = cir.pos.y + cir.rad * sin;
		verts[1 + i].color = fcolor;
	}
}

shared static this() {
	// bake
	foreach (const int i; 0 .. Renderer.nSinCos) {
		indicesCircleFan[3*i + 0] = 0; // center
		indicesCircleFan[3*i + 1] = 1 + i; // first vertex of edge
		indicesCircleFan[3*i + 2] = 1 + (i + 1) % Renderer.nSinCos; // next vertex
	}
}
static immutable int[3 * Renderer.nSinCos] indicesCircleFan; // TODO: tigh this to `bakeCircleFan` and circle shape somehow

SDL_FColor toFColor(in RGBA color) pure nothrow @nogc
	=> typeof(return)(color.r * fColor, color.g * fColor, color.b * fColor, color.a * fColor);

static immutable float fColor = 1.0f/255.0f;

alias Vertex = SDL_Vertex;
