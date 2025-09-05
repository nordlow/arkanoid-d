module entities;

import nxt.geometry;
import nxt.color : Color = ColorRGBA, Colors = RaylibColors;
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
		SDL_SetRenderDrawColor(rndr, color.r, color.g, color.b, color.a);
		SDL_RenderFillRect(rndr, &frect);
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
		// DrawCircleV(pos, rad, color);
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

struct BrickGrid {
	@disable this(this);
	this(in uint rows, in uint cols) {
		this.rows = rows;
		this.cols = cols;
		bricks = new Brick[rows * cols];
	}
	uint rows;
	uint cols;
	Brick[] bricks;
	void draw(SDL_Renderer* rndr) const nothrow {
		bricks.draw(rndr);
	}
}

struct Brick {
	union {
		Rect shape;
		SDL_FRect frect;
	}
	static immutable float FLASH_DURATION = 0.3f;
	Color color;
	bool active;
	bool isFlashing = false;
	float flashTimer = 0.0f; // Timer for flashing duration.
	void restartFlashing() scope pure nothrow @nogc {
		isFlashing = true; // start
		flashTimer = 0.0f; // restart
	}
	void draw(SDL_Renderer* rndr) const nothrow @trusted {
		if (active || isFlashing) {
			Color drawColor = color;
			if (isFlashing) {
				// Alternate between the original color and a bright white/yellow
				// to create the flashing effect.
				if (cast(int)(flashTimer * 10) % 2 == 0) {
					drawColor = Colors.WHITE;
				}
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
