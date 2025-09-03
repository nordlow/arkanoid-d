module entities;

import raylib;
alias Vec2 = Vector2;

@safe:

struct Paddle {
	Vec2 pos;
	Vec2 size;
	Color color;
	void draw() const @trusted {
		DrawRectangleV(pos, size, color);
	}
}

struct Bullet {
	Vec2 pos;
	float rad;
	Vec2 vel;
	Color color;
	bool active;
	void draw() const @trusted {
		if (active)
			DrawCircleV(pos, rad, color);
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
	void draw() const @trusted {
		bricks.drawN();
	}
}

struct Brick/+Tegelsten+/ {
	static immutable float FLASH_DURATION = 0.3f;
	Vec2 pos;
	Vec2 size;
	Color color;
	bool active;
	bool isFlashing = false;
	float flashTimer = 0.0f; // Timer for flashing duration.
	void draw() const @trusted {
		if (active || isFlashing) {
			Color drawColor = color;
			if (isFlashing) {
				// Alternate between the original color and a bright white/yellow
				// to create the flashing effect.
				if (cast(int)(flashTimer * 10) % 2 == 0) {
					drawColor = Colors.WHITE;
				}
			}
			DrawRectangleV(pos, size, drawColor);
		}
	}
}

/++ Draw generic entities `ents`.
	TODO: Fails to UFCS-called from `app.d` when named `draw`.
	+/
void drawN(T)(in T[] ents) @trusted {
	foreach (const ref ent; ents)
		ent.draw();
}

// TODO: Move to `nxt.geometry`
struct Circle {
	Vec2 centerPosition;
	float radius;
}

// TODO: Move to `nxt.geometry`
struct Square {
	Vec2 centerPosition;
	float radius;
}

// TODO: Move to `nxt.geometry`
struct Box {
	Vec2 centerPosition;
	Vec2 size;
}
