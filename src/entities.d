module entities;

import nxt.geometry;
import nxt.color : Color = ColorRGBA, ColorHSV;
import nxt.colors;

import sdl3;
import aliases;

@safe:

struct Paddle {
	union {
		Rect shape;
		SDL_FRect frect;
	}
	Color color;
	void draw(SDL_Renderer* rndr) const nothrow @trusted {
		SDL_SetRenderDrawColor(rndr, color);
		SDL_RenderFillRect(rndr, &frect);
	}
}

struct Ball {
	Pos2 pos;
	float rad;
	Vec2 vel;
	Color color;
	bool active;
	void draw(SDL_Renderer* rndr) const nothrow @trusted {
		if (active) {
			SDL_SetRenderDrawColor(rndr, color.r, color.g, color.b, color.a);
			drawFilledCircle(rndr, cast(int)pos.x, cast(int)pos.y, cast(int)rad);
		}
	}
}

// Helper function to draw filled circle using SDL rectangles
void drawFilledCircle(SDL_Renderer* rndr, int centerX, int centerY, int radius) nothrow @trusted {
	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			if (x*x + y*y <= radius*radius) {
				const rect = SDL_FRect(centerX + x, centerY + y, 1, 1);
				SDL_RenderFillRect(rndr, &rect);
			}
		}
	}
}

Ball[] makeBalls(uint count, Vec2 ballVelocity, uint screenWidth, uint screenHeight) {
	typeof(return) ret;
	ret.length = count;
	foreach (const i, ref ball; ret)
		ball = Ball(pos: Pos2(screenWidth / 2 + i * 20 - 20, screenHeight - 150),
					vel: ballVelocity,
					rad: 15,
					color: Colors.GRAY,
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

				const tangent = Vec2(-normal.y, normal.x);

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
	Pos2 pos;
	float rad;
	Vec2 vel;
	Color color;
	bool active;
	void draw(SDL_Renderer* rndr) const nothrow @trusted {
		if (!active)
			return;
		SDL_SetRenderDrawColor(rndr, color);
		// SDL_RenderFillRect(rndr, &frect);
	}
}

Bullet makeBullet() {
	typeof(return) ret;
	ret.active = false;
	ret.rad = 10; // radie, 2*radie == diameter
	ret.color = Colors.YELLOW;
	ret.vel = Vec2(0, -333);
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
	void layout(in int screenWidth, in int screenHeight, in Color topLeft, in Color topRight, in Color bottomLeft, in Color bottomRight) scope pure nothrow @safe @nogc {
		const entWidth = cast(float)screenWidth / nCols;
		const entHeight = cast(float)screenHeight / nRows / 2;
		foreach (const row; 0 .. nRows) {
			foreach (const col; 0 .. nCols) {
				const index = row * nCols + col;

				// Calculate interpolation factors (0.0 to 1.0) for row and column
				const t_col = cast(float)col / (nCols - 1);
				const t_row = cast(float)row / (nRows - 1);

				// Interpolate colors horizontally at the top and bottom of the grid
				const top_lerp = lerpClamped(topLeft, topRight, t_col);
				const bottom_lerp = lerpClamped(bottomLeft, bottomRight, t_col);

				// Interpolate vertically to find the final color for the current entity
				const finalColor = lerpClamped(top_lerp, bottom_lerp, t_row);

				// Set the entity's position, dimensions, and color
				ents[index] = Ent(shape: Rect(pos: Pos2(cast(int)(col * entWidth), cast(int)(row * entHeight)),
											  dim: Dim2(cast(int)(entWidth - 2), cast(int)(entHeight - 2))),
								  color: finalColor, true);
			}
		}
	}

	void draw(SDL_Renderer* rndr) nothrow {
		ents.draw(rndr);
	}

	inout(Ent)[] opSlice() inout return => ents;

	uint nRows; ///< Number of nRows.
	uint nCols; ///< Number of columns.
	private Ent[] ents; ///< Entities.
}

alias BrickGrid = RectGrid!Brick;

Color lerpClamped(in Color x, in Color y, float t) pure nothrow @nogc {
	import std.algorithm.comparison : clamp;
	t = clamp(t, 0, 1);
	import nxt.interpolation : lerp;
	auto r = lerp(x.r, y.r, t);
	auto g = lerp(x.g, y.g, t);
	auto b = lerp(x.b, y.b, t);
	auto a = lerp(x.a, y.a, t);
	return Color(cast(ubyte)r, cast(ubyte)g, cast(ubyte)b, cast(ubyte)a);
}

struct Brick {
	static immutable float FLASH_DURATION = 0.3f;
	union {
		Rect shape;
		SDL_FRect frect;
	}
	Color color;
	bool active;
	bool isFlashing = false;
	float flashTimer = 0.0f; // Timer for flashing duration.
nothrow:
	void restartFlashing() scope pure @nogc {
		isFlashing = true; // start
		flashTimer = 0.0f; // restart
	}
	void draw(SDL_Renderer* rndr) const @trusted {
		if (active || isFlashing) {
			Color drawColor = color;
			if (isFlashing) {
				// Alternate between the original color and a bright white/yellow
				// to create the flashing effect.
				if (cast(int)(flashTimer * 10) % 2 == 0)
					drawColor = Colors.WHITE;
			}
			SDL_SetRenderDrawColor(rndr, drawColor.r, drawColor.g, drawColor.b, drawColor.a);
			SDL_RenderFillRect(rndr, &frect);
		}
	}
}

/++ Draw generic entities `ents`. +/
void draw(T)(in T[] ents, SDL_Renderer* rndr) {
	foreach (const ref ent; ents)
		ent.draw(rndr);
}
