module entities;

import nxt.geometry;
import nxt.color : Color = ColorRGBA, Colors;
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

/++	Rectangular Grid. +/
struct RectGrid(Ent) {
	@disable this(this);
	this(in uint rows, in uint cols) {
		this.rows = rows;
		this.cols = cols;
		bricks = new Ent[rows * cols];
	}
	uint rows;
	uint cols;
	Ent[] bricks;
}
alias BrickGrid = RectGrid!Brick;

void draw(Ent)(ref RectGrid!(Ent) grid, SDL_Renderer* rndr) nothrow {
	grid.bricks.draw(rndr);
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
