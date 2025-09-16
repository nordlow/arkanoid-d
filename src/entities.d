module entities;

import base;

@safe:

struct Paddle {
	Rect shape;
	alias this = shape;
	RGBA color;
nothrow:
	void update(float dt) {}
	void drawIn(scope ref Renderer rdr) const scope @trusted {
		rdr.drawColor = color;
		rdr.fillRect(*cast(SDL_FRect*)&shape);
	}
	void moveLeft(in float deltaTime, in ScreenSize _ssz) {
		if (pos.x > 0)
			pos.x -= 800 * deltaTime;
	}
	void moveRight(in float deltaTime, in ScreenSize ssz) {
		if (pos.x < ssz.width - size.x)
			pos.x += 800 * deltaTime;
	}
}

// TODO: Factor out circle + color rendering into `struct Circle` here
struct Ball {
	Cir shape;
	alias this = shape;
	Vel velocity;
	RGBA color;
	bool active;
nothrow:
	void update(in float dt) scope pure nothrow @nogc { // TODO: Move to generic updater for types that have both position and velocity
		shape.center += velocity * dt;
	}
	this(Cir shape, Vel velocity, RGBA color, bool active) nothrow {
		this.shape = shape;
		this.velocity = velocity;
		this.color = color;
		this.active = active;
		bake();
	}
	void drawIn(scope ref Renderer rdr) const scope @trusted {
		if (!active) return;
		if (!pos.equals(_verts[0].position)) // `_verts` still in sync with `shape`
			rdr.bakeCircleFan(shape, _fcolor, (cast()this)._verts);
		rdr.renderGeometry(_verts, indicesCircleFan);
	}
	private void bake() {
		_fcolor = color.toFColor; // TODO: move to `color` @property setter
	}
private:
	// Cached values:
	SDL_FColor _fcolor; // computed from `color`
	SDL_Vertex[1 + Renderer.nSinCos] _verts; // computed from `shape`
}

bool equals(in Pos pos, in SDL_FPoint a) pure nothrow @nogc {
	return a.x == pos.x && a.y == pos.y;
}

Ball[] makeBalls(uint count, Vel velocity, uint screenWidth, uint screenHeight) {
	import nxt.io.dbg;
	auto rnd = Random();
	typeof(return) ret;
	ret.length = count;
	const rad = 16;
	foreach (const i, ref ball; ret)
		ball = Ball(shape: Cir(pos: Pos(screenWidth / 2 + i,
										(screenHeight - screenHeight / 8) + i),
							   rad: rad),
					velocity: velocity,
					color: HSV(uniform(0.0f, 1.0f, rnd), 0.5f, 0.8f).toRGBA,
					active: true);
	return ret;
}

struct Bullet {
	Cir shape;
	alias this = shape;
	Vel vel;
	RGBA color;
	bool active;
	void update(float dt) {}
	void drawIn(scope ref Renderer rdr) const scope nothrow @trusted {
		if (!active) return;
		rdr.drawColor = color;
		const d = 2*rad;
		rdr.fillRect(SDL_FRect(x: pos.x - rad, y: pos.y - rad, w: d, h: d));
	}
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

				const v1n = dot(ballA.velocity, normal);
				const v1t = dot(ballA.velocity, tangent);
				const v2n = dot(ballB.velocity, normal);
				const v2t = dot(ballB.velocity, tangent);

				const v1n_prime = v2n;
				const v2n_prime = v1n;

				ballA.velocity = (normal * v1n_prime) + (tangent * v1t);
				ballB.velocity = (normal * v2n_prime) + (tangent * v2t);
			}
		}
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
											  size: Dim(cast(int)(entWidth - 2), cast(int)(entHeight - 2))),
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
	void update(float dt) {}
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
