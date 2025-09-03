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

	Paddle paddle = {
		position: Vec2(screenWidth / 2 - 60, screenHeight - 30),
		size: Vec2(250, 20),
		color: Colors.BLUE
	};

	auto brickGrid = BrickGrid(rows: 15, cols: 20);
	brickGrid.bricks.layoutBricks(screenWidth, screenHeight, brickGrid.rows, brickGrid.cols);

	game.bullets = makeBullets(30);

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
			if (IsKeyDown(KeyboardKey.KEY_LEFT) && paddle.position.x > 0) {
				paddle.position.x -= 800 * deltaTime;
			}
			if (IsKeyDown(KeyboardKey.KEY_RIGHT)
				&& paddle.position.x < screenWidth - paddle.size.x) {
				paddle.position.x += 800 * deltaTime;
			}
			if (IsKeyPressed(KeyboardKey.KEY_SPACE)) {
				foreach (ref bullet; game.bullets) {
					if (!bullet.active) {
						bullet.position = Vec2(paddle.position.x + paddle.size.x / 2, paddle.position.y);
						bullet.active = true;
						game.shootSound.PlaySound();
						break;
					}
				}
			}

			game.balls[].bounceAll();

			foreach (ref ball; game.balls) {
				if (!ball.active) continue;
				ball.position.x += ball.velocity.x * deltaTime;
				ball.position.y += ball.velocity.y * deltaTime;
				if (ball.position.x <= ball.radius || ball.position.x >= screenWidth - ball.radius) {
					ball.velocity.x *= -1;
					game.wallSound.PlaySound();
				}
				if (ball.position.y <= ball.radius) {
					ball.velocity.y *= -1;
					game.wallSound.PlaySound();
				}
				if (ball.position.y + ball.radius >= paddle.position.y
					&& ball.position.y - ball.radius
					<= paddle.position.y + paddle.size.y
					&& ball.position.x >= paddle.position.x
					&& ball.position.x <= paddle.position.x + paddle.size.x) {
					ball.velocity.y = -abs(ball.velocity.y);
					game.paddleSound.PlaySound();
					const float hitPos = (ball.position.x - paddle.position.x) / paddle.size.x;
					ball.velocity.x = 200 * (hitPos - 0.5f) * 2;
				}
				foreach (ref brick; brickGrid.bricks) {
					if (!brick.active || brick.isFlashing)
						continue;
					if (ball.position.x + ball.radius >= brick.position.x
						&& ball.position.x - ball.radius
						<= brick.position.x + brick.size.x
						&& ball.position.y + ball.radius >= brick.position.y
						&& ball.position.y - ball.radius
						<= brick.position.y + brick.size.y) {
						brick.restartFlashing();
						ball.velocity.y *= -1;
						PlaySound(game.brickSound);
						break;
					}
				}
				if (ball.position.y > screenHeight) {
					ball.active = false;
				}
			}
			foreach (ref bullet; game.bullets) {
				if (bullet.active) {
					bullet.position.x += bullet.velocity.x * deltaTime;
					bullet.position.y += bullet.velocity.y * deltaTime;
					if (bullet.position.y < 0) {
						bullet.active = false;
					}
					foreach (ref brick; brickGrid.bricks) {
						if (!brick.active || brick.isFlashing)
							continue;
						if (bullet.position.x + bullet.radius >= brick.position.x
							&& bullet.position.x - bullet.radius
							<= brick.position.x + brick.size.x
							&& bullet.position.y + bullet.radius >= brick.position.y
							&& bullet.position.y - bullet.radius
							<= brick.position.y + brick.size.y) {
							restartFlashing(brick); // Start flashing
							bullet.active = false;
							PlaySound(game.brickSound);
							break;
						}
					}
				}
			}

			// Update logic for flashing bricks
			foreach (ref brick; brickGrid.bricks) {
				if (brick.isFlashing) {
					brick.flashTimer += deltaTime;
					if (brick.flashTimer >= FLASH_DURATION) {
						brick.active = false; // Deactivate the brick after flashing
						brick.isFlashing = false; // Reset flashing state
					}
				}
			}

			bool allBricksDestroyed = true;
			foreach (const brick; brickGrid.bricks) {
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
				ball.position = Vec2(screenWidth / 2 + (game.ballCountMax - 1) * 20 - 20, screenHeight - 150);
				ball.velocity = game.ballVelocity;
				ball.active = true;
			}
			paddle.position = Vec2(screenWidth / 2 - 60, screenHeight - 30);
			foreach (ref brick; brickGrid.bricks) {
				brick.active = true;
				brick.isFlashing = false; // Reset flashing state on restart
				brick.flashTimer = 0.0f;
				if (brick.position.y + brick.size.y < 250 + 2 * 30)
					brick.color = Colors.RED;
				else if (brick.position.y + brick.size.y < 250 + 4 * 30)
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
		brickGrid.bricks.drawBricks();
		paddle.drawPaddle();
		game.balls.drawBalls();
		game.bullets.drawBullets();
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
		balls = makeBalls(ballCountMax, ballVelocity, screenWidth, screenHeight);
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
	enum ballCountMax = 10; // Maximum number of balls
	Ball[ballCountMax] balls;
	Bullet[] bullets;

	static immutable soundSampleRate = 44100;
	Random rng;
	Sound paddleSound, wallSound, brickSound, shootSound;
	bool playMusic;

	bool won;
	bool over;
}

struct Paddle {
	Vec2 position;
	Vec2 size;
	ColorR8G8B8A8 color;
}

void drawPaddle(in Paddle paddle) @trusted {
	DrawRectangleV(paddle.position, paddle.size, paddle.color);
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
}

struct Brick/+Tegelsten+/ {
	Vec2 position;
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
			bricks[index] = Brick(position: Vec2(col * brickWidth,
											   row * brickHeight + 250),
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
		DrawRectangleV(brick.position, brick.size, drawColor);
	}
}

void drawBricks(in Brick[] bricks) @trusted {
	foreach (const ref brick; bricks)
		brick.drawBrick();
}

/++ Skott. +/
struct Bullet {
	Vec2 position;
	Vec2 velocity/+hastighet+/;
	float radius;
	ColorR8G8B8A8 color;
	bool active;
}

Bullet makeBullet() {
	typeof(return) ret;
	ret.active = false;
	ret.radius = 10; // radie, 2*radie == diameter
	ret.color = Colors.YELLOW;
	ret.velocity = Vec2(0, -333);
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
		DrawCircleV(bullet.position, bullet.radius, bullet.color);
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
	Vec2 position;
	Vec2 velocity;
	float radius;
	ColorR8G8B8A8 color;
	bool active; // Added to track active balls
}

Ball[] makeBalls(uint count, Vec2 ballVelocity, uint screenWidth, uint screenHeight) {
	typeof(return) ret;
	ret.length = count;
	foreach (const i, ref ball; ret)
		ball = Ball(position: Vec2(screenWidth / 2 + i * 20 - 20, screenHeight - 150),
					velocity: ballVelocity,
					radius: 15,
					color: Colors.GRAY,
					active: true
					);
	return ret;
}

void drawBalls(in Ball[] balls) @trusted {
	foreach (const ref ball; balls) {
		if (!ball.active)
			continue;
		DrawCircleV(ball.position, ball.radius, ball.color);
	}
}

void bounceAll(ref Ball[] balls) pure nothrow @nogc { // studsa alla
	foreach (i, ref Ball ballA; balls) {
		foreach (ref Ball ballB; balls[i + 1 .. $]) {
			if (!ballA.active || !ballB.active)
				continue;

			const delta = ballB.position - ballA.position;
			const distanceSquared = delta.lengthSquared;
			const combinedRadii = ballA.radius + ballB.radius;
			const combinedRadiiSquared = combinedRadii * combinedRadii;

			if (distanceSquared < combinedRadiiSquared) {
				const distance = distanceSquared.sqrt;
				const overlap = combinedRadii - distance;
				const normal = delta.normalized;

				ballA.position -= normal * (overlap / 2.0f);
				ballB.position += normal * (overlap / 2.0f);

				const tangent = Vec2(-normal.y, normal.x);

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
