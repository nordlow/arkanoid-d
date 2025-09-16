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

struct Ball {
	Cir shape;
	alias this = shape;
	Vel vel;
	RGBA color;
	bool active;
nothrow:
	void update(float dt) {}
	this(Cir shape, Vel vel, RGBA color, bool active) nothrow {
		this.shape = shape;
		this.vel = vel;
		this.color = color;
		this.active = active;
		generate();
	}
	void generate() {
		_fcolor = SDL_FColor(color.r * fColor,
							 color.g * fColor,
							 color.b * fColor,
							 color.a * fColor);
		foreach (const int i; 0 .. Renderer.nSinCos) {
			_indices[0 + 3 * i] = 0; // center
			_indices[1 + 3 * i] = i;
			_indices[2 + 3 * i] = (i + 1) % Renderer.nSinCos;
		}
	}
	void drawIn(scope ref Renderer rdr) const scope @trusted {
		if (!active)
			return;

		scope ref mthis = cast()this;

		// center
		mthis._verts[0].position.x = pos.x;
		mthis._verts[0].position.y = pos.y;
		mthis._verts[0].color = _fcolor;

		// circumference
		foreach (const int i; 0 .. Renderer.nSinCos) {
			const auto te = rdr._sincos[i]; // table entry
			const auto sin = te[0]; // sin
			const auto cos = te[1]; // cos
			mthis._verts[1 + i].position.x = pos.x + rad * cos;
			mthis._verts[1 + i].position.y = pos.y + rad * sin;
			mthis._verts[1 + i].color = _fcolor;
		}

		rdr.renderGeometry(_verts[], _indices[]);
	}
private:
	// Cached values:
	SDL_FColor _fcolor; // computed from `color`
	SDL_Vertex[1 + Renderer.nSinCos] _verts; // computed from `shape`
	int[3 * Renderer.nSinCos] _indices; // TODO: make this `static immutable` and compute in `shared static this`
}

/+ shared static this { +/
/+ } +/

static immutable float fColor = 1.0f/255.0f;

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
					vel: velocity,
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
		if (!active)
			return;
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
