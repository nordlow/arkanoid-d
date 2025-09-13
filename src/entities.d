module entities;

import nxt.geometry;
import nxt.color;
import nxt.colors;

import std.random : Random, uniform;
import nxt.sampling : sample;

import sdl;
import aliases;
import renderer;

alias RGBA = ColorRGBA;

@safe:

version(none) // TODO: move to renderer
struct Circle {
	Cir shape;
	RGBA color;
	// TODO: move these to `Renderer` for all objects in scene which
	// may require each entity to reference an immutable set of
	auto tesselate(uint vertexCount = 32) scope pure nothrow
		=> _vertices = new SDL_Vertex[vertexCount];
	void drawIn(scope ref Renderer rdr) const scope nothrow @trusted {
		SDL_SetRenderDrawColor(rdr._ptr, color);
		version(none) SDL_RenderGeometry(renderer, NULL, vertices, 3, NULL, 0);
	}
private:
	SDL_Vertex[] _vertices;
}

struct Paddle {
	Rect shape;
	RGBA color;
	void drawIn(scope ref Renderer rdr) const scope nothrow @trusted {
		SDL_SetRenderDrawColor(rdr._ptr, color);
		SDL_RenderFillRect(rdr._ptr, cast(SDL_FRect*)&shape);
	}
}

struct Ball {
	Pos pos;
	float rad;
	Vel2 vel;
	RGBA color;
	bool active;
	void drawIn(scope ref Renderer rdr) const scope nothrow @trusted {
		if (active) {
			SDL_SetRenderDrawColor(rdr._ptr, color.r, color.g, color.b, color.a);
			drawFilledCircle(rdr._ptr, cast(int)pos.x, cast(int)pos.y, cast(int)rad);
		}
	}
}

// Helper function to drawIn filled circle using SDL rectangles
void drawFilledCircle(SDL_Renderer* rdr, int centerX, int centerY, int radius) nothrow @trusted {
	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			if (x*x + y*y <= radius*radius) {
				const rect = SDL_FRect(centerX + x, centerY + y, 1, 1);
				SDL_RenderFillRect(rdr, &rect);
			}
		}
	}
}

Ball[] makeBalls(uint count, Vel2 velocity, uint screenWidth, uint screenHeight) {
	import nxt.io.dbg;
	auto rnd = Random();
	typeof(return) ret;
	ret.length = count;
	foreach (const i, ref ball; ret)
		ball = Ball(pos: Pos(screenWidth / 2 + i,
							  screenHeight / 16 + i),
					vel: velocity,
					rad: 15,
					color: HSV(uniform(0.0f, 1.0f, rnd), 0.5f, 0.8f).toRGBA,
					active: true);
	return ret;
}

void bounceAll(ref Ball[] balls) pure nothrow @nogc {
	foreach (i, ref Ball ballA; balls) {
		foreach (ref Ball ballB; balls[i + 1 .. $]) {
			if (!ballA.active || !ballB.active)
				continue;

			const delta = ballB.pos - ballA.pos;
			const distSqr = delta.magnitudeSquared;
			const combinedRadii = ballA.rad + ballB.rad;
			const combinedRadiiSquared = combinedRadii * combinedRadii;
			const bool isOverlap = distSqr < combinedRadiiSquared;
			if (isOverlap) {
				import std.math : sqrt;
				const dist = distSqr.sqrt;
				const overlap = combinedRadii - dist;
				const normal = delta.normalized;

				ballA.pos -= normal * (overlap / 2.0f);
				ballB.pos += normal * (overlap / 2.0f);

				const tangent = Vec(-normal.y, normal.x);

				const v1n = dot(ballA.vel, normal);
				const v1t = dot(ballA.vel, tangent);
				const v2n = dot(ballB.vel, normal);
				const v2t = dot(ballB.vel, tangent);

				const v1n_prime = v2n;
				const v2n_prime = v1n;

				ballA.vel = (normal * v1n_prime) + (tangent * v1t);
				ballB.vel = (normal * v2n_prime) + (tangent * v2t);
			}
		}
	}
}

struct Bullet {
	// TODO: Use Rect
	Pos pos;
	float rad;
	Vel2 vel;
	RGBA color;
	bool active;
	void drawIn(scope ref Renderer rdr) const scope nothrow @trusted {
		if (!active)
			return;
		SDL_SetRenderDrawColor(rdr._ptr, color);
		auto frect = SDL_FRect(x: pos.x-rad, y: pos.y-rad, w: 2*rad, h: 2*rad);
		SDL_RenderFillRect(rdr._ptr, &frect);
	}
}

Bullet makeBullet() {
	typeof(return) ret;
	ret.active = false;
	ret.rad = 3; // radie, 2*radie == diameter
	ret.color = Colors.YELLOW;
	ret.vel = Vec(0, -333);
	return ret;
}

Bullet[] makeBullets(uint count) {
	typeof(return) ret;
	ret.length = count;
	foreach (ref bullet; ret)
		bullet = makeBullet();
	return ret;
}

/// Rectangular Grid of entities all of type `Ent`.
struct RectGrid(Ent) {
	@disable this(this);
	this(in uint nRows, in uint nCols) {
		this.nRows = nRows;
		this.nCols = nCols;
		ents = new Ent[nRows * nCols];
	}

	/// Lays out the entities in a rectangular grid with a 2D color gradient.
	void layout(in int screenWidth, in int screenHeight, in RGBA topLeft, in RGBA topRight, in RGBA bottomLeft, in RGBA bottomRight) scope pure nothrow @safe @nogc {
		const entWidth = cast(float)screenWidth / nCols;
		const entHeight = cast(float)screenHeight / nRows / 2;
		foreach (const row; 0 .. nRows) {
			foreach (const col; 0 .. nCols) {
				const index = row * nCols + col;

				// TODO: factor out to two-dimensional `lerp`:
				// interpolation factors (0.0 to 1.0) for row and column
				const t_col = cast(float)col / (nCols - 1);
				const t_row = cast(float)row / (nRows - 1);
				// interpolate colors horizontally at the top and bottom of the grid
				import nxt.interpolation : lerp;
				const top_lerp = t_col.lerp(topLeft, topRight);
				const bottom_lerp = t_col.lerp(bottomLeft, bottomRight);
				// interpolate vertically to find the final color for the current entity
				const finalColor = t_row.lerp(top_lerp, bottom_lerp);

				// set the entity's position, dimensions, and color
				ents[index] = Ent(shape: Rect(pos: Pos(cast(int)(col * entWidth ),
														screenHeight/8 + cast(int)(row * entHeight)),
											  size: Dim2(cast(int)(entWidth - 2), cast(int)(entHeight - 2))),
								  color: finalColor, true);
			}
		}
	}

	void drawIn(scope ref Renderer rdr) nothrow {
		ents.drawIn(rdr);
	}

	inout(Ent)[] opSlice() inout return scope => ents;

	uint nRows; ///< Number of nRows.
	uint nCols; ///< Number of columns.
	private Ent[] ents; ///< Entities.
}

alias BrickGrid = RectGrid!Brick;

struct Brick {
	static immutable float FLASH_DURATION = 0.3f;
	Rect shape;
	RGBA color;
	bool active;
	bool isFlashing = false;
	float flashTimer = 0.0f;
nothrow:
	void restartFlashing() scope pure @nogc {
		isFlashing = true; // start
		flashTimer = 0.0f; // restart
	}
	void drawIn(scope ref Renderer rdr) const @trusted {
		if (active || isFlashing) {
			RGBA drawColor = color;
			if (isFlashing) {
				// Alternate between the original color and a bright white/yellow
				// to create the flashing effect.
				if (cast(int)(flashTimer * 10) % 2 == 0)
					drawColor = Colors.WHITE;
			}
			SDL_SetRenderDrawColor(rdr._ptr, drawColor.r, drawColor.g, drawColor.b, drawColor.a);
			SDL_RenderFillRect(rdr._ptr, cast(SDL_FRect*)&shape);
		}
	}
}

/++ Draw generic entities `ents`. +/
void drawIn(T)(in T[] ents, scope ref Renderer rdr) {
	foreach (const ref ent; ents)
		ent.drawIn(rdr);
}
