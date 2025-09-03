import core.time : Duration;

import std.random : uniform, Random, unpredictableSeed;
import std.math : abs, sqrt;

import nxt.io : writeln;
import nxt.geometry;
import nxt.color : ColorRGBA;

import raylib;
alias Vec2 = Vector2;

import entities;
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
		writeln("ERROR: Audio device not ready!");

	auto game = Game(screenWidth, screenHeight);

	Sound[] pianoSounds;
	pianoSounds.reserve(game.pianoKeys.length);
	foreach (const i, const key; game.pianoKeys[0 .. 40]) {
		const f = cast(float)__traits(getMember, Key, key);
		pianoSounds ~= generatePianoWave(f, 1.0f, 1.0f, game.soundSampleRate).LoadSoundFromWave();
	}

	game.scene.paddle = Paddle(pos: Vec2(screenWidth / 2 - 60, screenHeight - 30),
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
			if (IsKeyDown(KeyboardKey.KEY_LEFT) && game.scene.paddle.pos.x > 0)
				game.scene.paddle.pos.x -= 800 * deltaTime;
			if (IsKeyDown(KeyboardKey.KEY_RIGHT) && game.scene.paddle.pos.x < screenWidth - game.scene.paddle.size.x)
				game.scene.paddle.pos.x += 800 * deltaTime;
			if (IsKeyPressed(KeyboardKey.KEY_SPACE)) {
				foreach (ref bullet; game.scene.bullets) {
					if (bullet.active)
						continue;
					bullet.pos = Vec2(game.scene.paddle.pos.x + game.scene.paddle.size.x / 2, game.scene.paddle.pos.y);
					bullet.active = true;
					game.shootSound.PlaySound();
					break;
				}
			}

			game.scene.balls[].bounceAll();

			foreach (ref ball; game.scene.balls) {
				if (!ball.active) continue;
				ball.pos += ball.vel * deltaTime;
				if (ball.pos.x <= ball.rad || ball.pos.x >= screenWidth - ball.rad) {
					ball.vel.x *= -1;
					game.wallSound.PlaySound();
				}
				if (ball.pos.y <= ball.rad) {
					ball.vel.y *= -1;
					game.wallSound.PlaySound();
				}
				if (ball.pos.y + ball.rad >= game.scene.paddle.pos.y
					&& ball.pos.y - ball.rad
					<= game.scene.paddle.pos.y + game.scene.paddle.size.y
					&& ball.pos.x >= game.scene.paddle.pos.x
					&& ball.pos.x <= game.scene.paddle.pos.x + game.scene.paddle.size.x) {
					ball.vel.y = -abs(ball.vel.y);
					game.paddleSound.PlaySound();
					const float hitPos = (ball.pos.x - game.scene.paddle.pos.x) / game.scene.paddle.size.x;
					ball.vel.x = 200 * (hitPos - 0.5f) * 2;
				}
				foreach (ref brick; game.scene.brickGrid.bricks) {
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
				if (ball.pos.y > screenHeight) { // TODO: Change this condition.
					ball.active = false;
				}
			}
			foreach (ref bullet; game.scene.bullets) {
				if (bullet.active) {
					bullet.pos += bullet.vel * deltaTime;
					if (bullet.pos.y < 0)
						bullet.active = false;
					foreach (ref brick; game.scene.brickGrid.bricks) {
						if (!brick.active || brick.isFlashing)
							continue;
						if (bullet.pos.x + bullet.rad >= brick.pos.x
							&& bullet.pos.x - bullet.rad
							<= brick.pos.x + brick.size.x
							&& bullet.pos.y + bullet.rad >= brick.pos.y
							&& bullet.pos.y - bullet.rad
							<= brick.pos.y + brick.size.y) {
							brick.restartFlashing();
							bullet.active = false;
							PlaySound(game.brickSound);
							break;
						}
					}
				}
			}

			// Update logic for flashing bricks
			foreach (ref brick; game.scene.brickGrid.bricks) {
				if (brick.isFlashing) {
					brick.flashTimer += deltaTime;
					if (brick.flashTimer >= Brick.FLASH_DURATION) {
						brick.active = false; // Deactivate the brick after flashing
						brick.isFlashing = false; // Reset flashing state
					}
				}
			}

			bool allBricksDestroyed = true;
			foreach (const brick; game.scene.brickGrid.bricks) {
				if (brick.active) {
					allBricksDestroyed = false;
					break;
				}
			}
			game.won = allBricksDestroyed;
			bool allBallsLost = true;
			foreach (const ball; game.scene.balls) {
				if (ball.active) {
					allBallsLost = false;
					break;
				}
			}
			game.over = allBallsLost;
		}
		if ((game.over || game.won) && IsKeyPressed(KeyboardKey.KEY_R)) {
			foreach (ref ball; game.scene.balls) {
				ball.pos = Vec2(screenWidth / 2 + (game.scene.balls.length - 1) * 20 - 20, screenHeight - 150);
				ball.vel = game.ballVelocity;
				ball.active = true;
			}
			game.scene.paddle.pos = Vec2(screenWidth / 2 - 60, screenHeight - 30);
			foreach (ref brick; game.scene.brickGrid.bricks) {
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
			foreach (ref bullet; game.scene.bullets)
				bullet.active = false;
			game.over = false;
			game.won = false;
		}

		BeginDrawing();
		clearCanvas();
		game.scene.draw();
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
		scene = Scene(balls: makeBalls(ballCount, ballVelocity, screenWidth, screenHeight),
					  bullets: makeBullets(30),
					  brickGrid: BrickGrid(rows: 15, cols: 20));
		scene.brickGrid.bricks.layoutBricks(screenWidth, screenHeight, scene.brickGrid.rows, scene.brickGrid.cols);

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

	static immutable ballCount = 10;
	const ballVelocity = Vec2(100, -200); // boll hastighet

	Scene scene;

	static immutable soundSampleRate = 44100;
	Random rng;
	Sound paddleSound, wallSound, brickSound, shootSound;
	bool playMusic;

	bool won;
	bool over;
}

struct Scene {
	@disable this(this);
	Paddle paddle;
	Ball[] balls;
	Bullet[] bullets;
	BrickGrid brickGrid;
	void draw() {
		brickGrid.draw();
		paddle.draw();
		balls.draw();
		bullets.draw();
	}
}

void layoutBricks(scope Brick[] bricks, in int screenWidth, in int screenHeight, in int brickRows, in int brickCols) pure nothrow @nogc {
	const brickWidth = screenWidth / brickCols; // bredd
	const brickHeight = 30; // höjd
	foreach (const row; 0 .. brickRows) {
		foreach (const col; 0 .. brickCols) {
			const index = row * brickCols + col;
			bricks[index] = Brick(pos: Vec2(col * brickWidth, row * brickHeight + 250),
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
	Vec2 pos;
	float rad;
	Vec2 vel;
	Color color;
	bool active; // Added to track active balls
	void draw() const @trusted {
		if (active)
			DrawCircleV(pos, rad, color);
	}
}

Ball[] makeBalls(uint count, Vec2 ballVelocity, uint screenWidth, uint screenHeight) {
	typeof(return) ret;
	ret.length = count;
	foreach (const i, ref ball; ret)
		ball = Ball(pos: Vec2(screenWidth / 2 + i * 20 - 20, screenHeight - 150),
					vel: ballVelocity,
					rad: 15,
					color: Colors.GRAY,
					active: true
					);
	return ret;
}

/++ Bounce `balls`.

	See_Also: Symbols in raylib containing `CheckCollision`
 +/
void bounceAll(ref Ball[] balls) pure nothrow @nogc { // studsa alla
	foreach (i, ref Ball ballA; balls) {
		foreach (ref Ball ballB; balls[i + 1 .. $]) {
			if (!ballA.active || !ballB.active)
				continue;

			const delta = ballB.pos - ballA.pos;
			const distSqr = delta.lengthSquared;
			const combinedRadii = ballA.rad + ballB.rad;
			const combinedRadiiSquared = combinedRadii * combinedRadii;
			const bool isOverlap = distSqr < combinedRadiiSquared;
			if (isOverlap) {
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
