import core.time : Duration;
import std.stdio;
import std.algorithm : minElement, maxElement, sum;
import std.numeric;
import std.random : uniform, Random, unpredictableSeed;
import std.math;
import std.string;
import nxt.geometry;
import nxt.color : ColorRGB8;
import raylib;
import raylib : ColorR8G8B8A8 = Color;
import music;
import waves;
import joystick;

@safe:

void main() @trusted {
	SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
	validateRaylibBinding();

	InitWindow(800, 600, "Arkanoid Clone");
	const monitor = GetCurrentMonitor();
	SetWindowSize(GetMonitorWidth(monitor),
				  GetMonitorHeight(monitor));

	ToggleFullscreen();
	const screenWidth = GetScreenWidth();
	const screenHeight = GetScreenHeight();

	SetTargetFPS(60);

	InitAudioDevice();
	scope(exit) {
		CloseAudioDevice();
		CloseWindow();
	}
	if (!IsAudioDeviceReady())
		stderr.writeln("ERROR: Audio device not ready!");

	auto game = Game(screenWidth, screenHeight);

	if (false) raylib_detectGamepad();

	Sound[] pianoSounds;
	pianoSounds.reserve(game.pianoKeys.length);
	foreach (const i, const key; game.pianoKeys[0 .. 40]) {
		const f = cast(float)__traits(getMember, Key, key);
		pianoSounds ~= generatePianoWave(f, 1.0f, 1.0f, game.soundSampleRate).LoadSoundFromWave();
	}

	game.paddle = Paddle(posEnt: PositionedEntity(pos: Vec2(screenWidth / 2 - 60, screenHeight - 30)),
						 size: Vec2(250, 20),
						 color: Colors.BLUE);

	uint keyCounter;
	for (uint frameCounter; !WindowShouldClose(); ++frameCounter) {
		version(none)
			game.joystick.readPendingEvents();

		const deltaTime = GetFrameTime();
		const absTime = GetTime();

		if (game.playMusic && absTime > keyCounter) {
			pianoSounds[keyCounter].PlaySound();
			keyCounter += 1;
		}

		if (!game.over && !game.won) {
			if (IsKeyDown(KeyboardKey.KEY_LEFT) && game.paddle.pos.x > 0) {
				game.paddle.pos.x -= 800 * deltaTime;
			}
			if (IsKeyDown(KeyboardKey.KEY_RIGHT)
				&& game.paddle.pos.x < screenWidth - game.paddle.size.x) {
				game.paddle.pos.x += 800 * deltaTime;
			}
			if (IsKeyPressed(KeyboardKey.KEY_SPACE)) {
				foreach (ref bullet; game.bullets) {
					if (!bullet.active) {
						bullet.pos = Vec2(game.paddle.pos.x + game.paddle.size.x / 2, game.paddle.pos.y);
						bullet.active = true;
						game.shootSound.PlaySound();
						break;
					}
				}
			}

			game.balls[].bounceAll();

			foreach (ref ball; game.balls) {
				if (!ball.active) continue;
				ball.pos.x += ball.vel.x * deltaTime;
				ball.pos.y += ball.vel.y * deltaTime;
				if (ball.pos.x <= ball.rad || ball.pos.x >= screenWidth - ball.rad) {
					ball.vel.x *= -1;
					game.wallSound.PlaySound();
				}
				if (ball.pos.y <= ball.rad) {
					ball.vel.y *= -1;
					game.wallSound.PlaySound();
				}
				if (ball.pos.y + ball.rad >= game.paddle.pos.y
					&& ball.pos.y - ball.rad
					<= game.paddle.pos.y + game.paddle.size.y
					&& ball.pos.x >= game.paddle.pos.x
					&& ball.pos.x <= game.paddle.pos.x + game.paddle.size.x) {
					ball.vel.y = -abs(ball.vel.y);
					game.paddleSound.PlaySound();
					const float hitPos = (ball.pos.x - game.paddle.pos.x) / game.paddle.size.x;
					ball.vel.x = 200 * (hitPos - 0.5f) * 2;
				}
				foreach (ref brick; game.brickGrid.bricks) {
					if (!brick.active || brick.isFlashing)
						continue;
					if (ball.pos.x + ball.rad >= brick.pos.x
						&& ball.pos.x - ball.rad
						<= brick.pos.x + brick.size.x
						&& ball.pos.y + ball.rad >= brick.pos.y
						&& ball.pos.y - ball.rad
						<= brick.pos.y + brick.size.y) {
						brick.restartFlashing();
						ball.vel.y *= -1;
						PlaySound(game.brickSound);
						break;
					}
				}
				if (ball.pos.y > screenHeight) {
					ball.active = false;
				}
			}
			foreach (ref bullet; game.bullets) {
				if (bullet.active) {
					bullet.pos.x += bullet.vel.x * deltaTime;
					bullet.pos.y += bullet.vel.y * deltaTime;
					if (bullet.pos.y < 0) {
						bullet.active = false;
					}
					foreach (ref brick; game.brickGrid.bricks) {
						if (!brick.active || brick.isFlashing)
							continue;
						if (bullet.pos.x + bullet.rad >= brick.pos.x
							&& bullet.pos.x - bullet.rad
							<= brick.pos.x + brick.size.x
							&& bullet.pos.y + bullet.rad >= brick.pos.y
							&& bullet.pos.y - bullet.rad
							<= brick.pos.y + brick.size.y) {
							restartFlashing(brick); // Start flashing
							bullet.active = false;
							PlaySound(game.brickSound);
							break;
						}
					}
				}
			}

			// Update logic for flashing bricks
			foreach (ref brick; game.brickGrid.bricks) {
				if (brick.isFlashing) {
					brick.flashTimer += deltaTime;
					if (brick.flashTimer >= FLASH_DURATION) {
						brick.active = false; // Deactivate the brick after flashing
						brick.isFlashing = false; // Reset flashing state
					}
				}
			}

			bool allBricksDestroyed = true;
			foreach (const brick; game.brickGrid.bricks) {
				if (brick.active) {
					allBricksDestroyed = false;
					break;
				}
			}
			game.won = allBricksDestroyed;
			bool allBallsLost = true;
			foreach (const ball; game.balls) {
				if (ball.active) {
					allBallsLost = false;
					break;
				}
			}
			game.over = allBallsLost;
		}
		if ((game.over || game.won) && IsKeyPressed(KeyboardKey.KEY_R)) {
			foreach (ref ball; game.balls) {
				ball.pos = Vec2(screenWidth / 2 + (game.balls.length - 1) * 20 - 20, screenHeight - 150);
				ball.vel = game.ballVelocity;
				ball.active = true;
			}
			game.paddle.pos = Vec2(screenWidth / 2 - 60, screenHeight - 30);
			foreach (ref brick; game.brickGrid.bricks) {
				brick.active = true;
				brick.isFlashing = false; // Reset flashing state on restart
				brick.flashTimer = 0.0f;
				if (brick.pos.y + brick.size.y < 250 + 2 * 30)
					brick.color = Colors.RED;
				else if (brick.pos.y + brick.size.y < 250 + 4 * 30)
					brick.color = Colors.YELLOW;
				else
					brick.color = Colors.GREEN;
			}
			foreach (ref bullet; game.bullets) {
				bullet.active = false;
			}
			game.over = false;
			game.won = false;
		}

		BeginDrawing();
		clearCanvas();
		game.draw();
		EndDrawing();

		if (game.won) {
			const text = "YOU WON! Press R to restart";
			const fontSize = 32;
			const textWidth = MeasureText(text.ptr, fontSize);
			DrawText(text.ptr, (screenWidth - textWidth) / 2, screenHeight / 2,
					 fontSize, Colors.GREEN);
		} else if (game.over) {
			const text = "GAME OVER! Press R to restart";
			const fontSize = 32;
			const textWidth = MeasureText(text.ptr, fontSize);
			DrawText(text.ptr, (screenWidth - textWidth) / 2, screenHeight / 2,
					 fontSize, Colors.RED);
		} else {
			DrawText("LEFT/RIGHT arrows to move, SPACE to shoot".ptr, 10,
					 screenHeight - 25, 16, Colors.WHITE);
		}
	}
}

struct Game {
	@disable this(this);

	this(in uint screenWidth, in uint screenHeight) @trusted {
		joystick = openDefaultJoystick();
		rng = Random(unpredictableSeed());
		balls = makeBalls(ballCount, ballVelocity, screenWidth, screenHeight);
		bullets = makeBullets(30);
		brickGrid = BrickGrid(rows: 15, cols: 20);
		brickGrid.bricks.layoutBricks(screenWidth, screenHeight, brickGrid.rows, brickGrid.cols);
		generateSounds();
	}

	void generateSounds() @trusted {
		paddleSound = generateBoingWave(300.0f, 1000.0f, 0.30f, soundSampleRate).LoadSoundFromWave();
		wallSound = generateBoingWave(300.0f, 150.0f, 0.30f, soundSampleRate).LoadSoundFromWave();
		brickSound = rng.generateGlassBreakWave(0.60f, 0.2f, soundSampleRate).LoadSoundFromWave();
		shootSound = generateBounceWave(400.0f, 200.0f, 0.3f, soundSampleRate).LoadSoundFromWave();
	}

	private static immutable pianoKeys = __traits(allMembers, Key);

	Joystick joystick;

	const ballVelocity = Vec2(100, -800); // boll hastighet

	Paddle paddle;

	static immutable ballCount = 3;
	Ball[] balls;

	Bullet[] bullets;
	BrickGrid brickGrid;

	static immutable soundSampleRate = 44100;
	Random rng;
	Sound paddleSound, wallSound, brickSound, shootSound;
	bool playMusic;

	bool won;
	bool over;
}

void draw(in Game game) @trusted {
	game.brickGrid.draw();
	game.paddle.drawPaddle();
	game.balls.drawBalls();
	game.bullets.drawBullets();
}

/++ Common term for a game object. +/
struct Entity {
}

struct PositionedEntity {
	this(Vec2 pos) pure nothrow @nogc {
		this.pos = pos;
	}
	Entity ent;
	Vec2 pos;
}

struct Paddle {
	PositionedEntity posEnt; alias this = posEnt;
	Vec2 size;
	ColorR8G8B8A8 color;
}

void drawPaddle(in Paddle paddle) @trusted {
	DrawRectangleV(paddle.pos, paddle.size, paddle.color);
}

struct BrickGrid {
	Entity entity;
	@disable this(this);
	this(in uint rows, in uint cols) {
		this.rows = rows;
		this.cols = cols;
		bricks = new Brick[rows * cols];
	}
	uint rows;
	uint cols;
	Brick[] bricks;
}

void draw(in BrickGrid brickGrid) @trusted {
	brickGrid.bricks.drawBricks();
}

struct Brick/+Tegelsten+/ {
	PositionedEntity posEnt; alias this = posEnt;
	Entity entity;
	Vec2 size;
	ColorR8G8B8A8 color;
	bool active;
	bool isFlashing = false;
	float flashTimer = 0.0f; // Timer for flashing duration.
}

static immutable float FLASH_DURATION = 0.3f;

void restartFlashing(ref Brick brick) {
	brick.isFlashing = true; // start
	brick.flashTimer = 0.0f; // restart
}

void layoutBricks(scope Brick[] bricks, in int screenWidth, in int screenHeight, in int brickRows, in int brickCols) pure nothrow @nogc {
	const brickWidth = screenWidth / brickCols; // bredd
	const brickHeight = 30; // höjd
	foreach (const row; 0 .. brickRows) {
		foreach (const col; 0 .. brickCols) {
			const index = row * brickCols + col;
			bricks[index] = Brick(posEnt: PositionedEntity(Vec2(col * brickWidth,
											   row * brickHeight + 250)),
								  size: Vec2(brickWidth - 2,
											 brickHeight - 2),
								  Colors.RED, true);
			if (row < 2)
				bricks[index].color = Colors.RED;
			else if (row < 4)
				bricks[index].color = Colors.YELLOW;
			else
				bricks[index].color = Colors.GREEN;
		}
	}

}

void drawBrick(in Brick brick) @trusted {
	if (brick.active || brick.isFlashing) {
		ColorR8G8B8A8 drawColor = brick.color;
		if (brick.isFlashing) {
			// Alternate between the original color and a bright white/yellow
			// to create the flashing effect.
			if (cast(int)(brick.flashTimer * 10) % 2 == 0) {
				drawColor = Colors.WHITE;
			}
		}
		DrawRectangleV(brick.pos, brick.size, drawColor);
	}
}

void drawBricks(in Brick[] bricks) @trusted {
	foreach (const ref brick; bricks)
		brick.drawBrick();
}

/++ Skott. +/
struct Bullet {
	PositionedEntity posEnt; alias this = posEnt;
	Vec2 vel/+hastighet+/;
	float rad;
	ColorR8G8B8A8 color;
	bool active;
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

void drawBullet(in Bullet bullet) @trusted {
	if (bullet.active)
		DrawCircleV(bullet.pos, bullet.rad, bullet.color);
}

void drawBullets(in Bullet[] bullets) @trusted {
	foreach (const ref bullet; bullets)
		bullet.drawBullet();
}

alias Vec2 = Vector2;

float dot(in Vec2 v1, in Vec2 v2) pure nothrow @nogc {
	version(D_Coverage) {} else pragma(inline, true);
	return v1.x*v2.x + v1.y*v2.y;
}

float lengthSquared(in Vec2 v) pure nothrow @nogc {
	version(D_Coverage) {} else pragma(inline, true);
	return v.x*v.x + v.y*v.y;
}

float length(in Vec2 v) pure nothrow @nogc {
	version(D_Coverage) {} else pragma(inline, true);
	return v.lengthSquared.sqrt;
}

Vec2 normalized(in Vec2 v) pure nothrow @nogc {
	version(D_Coverage) {} else pragma(inline, true);
	const l = v.length;
	if (l == 0)
		return Vec2(0, 0);
	return v / l;
}

void clearCanvas() @trusted {
	ClearBackground(Colors.BLACK);
}

/++ Boll. +/
struct Ball {
	PositionedEntity posEnt; alias this = posEnt;
	Vec2 vel;
	float rad;
	ColorR8G8B8A8 color;
	bool active; // Added to track active balls
}

Ball[] makeBalls(uint count, Vec2 ballVelocity, uint screenWidth, uint screenHeight) {
	typeof(return) ret;
	ret.length = count;
	foreach (const i, ref ball; ret)
		ball = Ball(posEnt: PositionedEntity(Vec2(screenWidth / 2 + i * 20 - 20, screenHeight - 150)),
					vel: ballVelocity,
					rad: 15,
					color: Colors.GRAY,
					active: true
					);
	return ret;
}

void drawBalls(in Ball[] balls) @trusted {
	foreach (const ref ball; balls) {
		if (!ball.active)
			continue;
		DrawCircleV(ball.pos, ball.rad, ball.color);
	}
}

void bounceAll(ref Ball[] balls) pure nothrow @nogc { // studsa alla
	foreach (i, ref Ball ballA; balls) {
		foreach (ref Ball ballB; balls[i + 1 .. $]) {
			if (!ballA.active || !ballB.active)
				continue;

			const delta = ballB.pos - ballA.pos;
			const distSqr = delta.lengthSquared;
			const combinedRadii = ballA.rad + ballB.rad;
			const combinedRadiiSquared = combinedRadii * combinedRadii;

			if (distSqr < combinedRadiiSquared) {
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

void raylib_detectGamepad() @trusted {
	foreach (const gamepad; -1000 .. 1000) {
		if (IsGamepadAvailable(gamepad)) {
			const name = GetGamepadName(gamepad);
			writeln("Gamepad: nr ", gamepad, " being ", name.fromStringz, " detected");
			foreach (const button; -100 .. 100) {
				if (IsGamepadButtonDown(gamepad, button)) {
					writeln("Button ", button, " is down");
				}
			}
		}
	}
}
