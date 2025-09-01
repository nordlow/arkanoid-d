import core.time : Duration;
import std.stdio;
import std.algorithm : minElement, maxElement, sum;
import std.numeric;
import std.random : uniform, Random, unpredictableSeed;
import std.math;

import raylib;
import music;
import waves;

@safe:

alias Vec2 = Vector2;

struct Ball {
	Vec2 position;
	Vec2 velocity;
	float radius;
	Color color;
}

struct Paddle {
	Vec2 position;
	Vec2 size;
	Color color;
}

struct Brick {
	Vec2 position;
	Vec2 size;
	Color color;
	bool active;
}

struct Bullet {
	Vec2 position;
	Vec2 velocity;
	float radius;
	Color color;
	bool active;
}

void main() @trusted {
	validateRaylibBinding();

	// Create Window
	InitWindow(800, 600, "Arkanoid Clone");
	const monitor = GetCurrentMonitor();
    SetWindowSize(GetMonitorWidth(monitor),
				  GetMonitorHeight(monitor));
	ToggleFullscreen();
	const screenWidth = GetScreenWidth();
	const screenHeight = GetScreenHeight();
	SetTargetFPS(60);

	// Setup audio
	InitAudioDevice();
	scope(exit) {
		CloseAudioDevice();
		CloseWindow();
	}

	if (!IsAudioDeviceReady()) {
		stderr.writeln("ERROR: Audio device not ready!");
	} else {
		stdout.writeln("Audio device initialized successfully");
	}
	const sampleRate = 44100;

    auto rng = Random(unpredictableSeed());

	auto paddleSound = generateBoingWave(300.0f, 1000.0f, 0.30f, sampleRate).LoadSoundFromWave();
    auto wallSound = generateBoingWave(300.0f, 150.0f, 0.30f, sampleRate).LoadSoundFromWave();
    auto brickSound = rng.generateGlassBreakWave(0.60f, 0.2f, sampleRate).LoadSoundFromWave();
	auto shootSound = generateBounceWave(400.0f, 200.0f, 0.3f, sampleRate).LoadSoundFromWave();

	const playPiano = false;
	const pianoKeys = __traits(allMembers, Key);
	Sound[] pianoSounds;
	pianoSounds.reserve(pianoKeys.length);
	foreach (const i, const key; pianoKeys[0 .. 40]) {
		const f = cast(float)__traits(getMember, Key, key);
		pianoSounds ~= generatePianoWave(f, 1.0f, 1.0f, sampleRate).LoadSoundFromWave();
	}
	import std;

	Ball ball = {
		position: Vec2(screenWidth / 2, screenHeight - 150),
		velocity: Vec2(0, -800),
		radius: 10,
		color: Colors.WHITE
	};

	Paddle paddle = {
		position: Vec2(screenWidth / 2 - 60, screenHeight - 30),
		size: Vec2(250, 20),
		color: Colors.BLUE
	};

	const brickRows = 6;
	const brickCols = 20;
	const brickWidth = screenWidth / brickCols;
	const brickHeight = 30;
	Brick[brickRows * brickCols] bricks;

	foreach (const row; 0 .. brickRows) {
		foreach (const col; 0 .. brickCols) {
			const index = row * brickCols + col;
			bricks[index] = Brick(
				Vec2(col * brickWidth, row * brickHeight + 50),
				Vec2(brickWidth - 2, brickHeight - 2), Colors.RED, true);

			if (row < 2)
				bricks[index].color = Colors.RED;
			else if (row < 4)
				bricks[index].color = Colors.YELLOW;
			else
				bricks[index].color = Colors.GREEN;
		}
	}

	enum maxBullets = 10;
	Bullet[maxBullets] bullets;
	foreach (const i; 0 .. maxBullets) {
		bullets[i].active = false;
		bullets[i].radius = 3;
		bullets[i].color = Colors.YELLOW;
		bullets[i].velocity = Vec2(0, -333);
	}

	bool gameWon = false;
	bool gameOver = false;

	uint frameCounter;
	uint keyCounter;
	while (!WindowShouldClose()) {
		const deltaTime = GetFrameTime();
		const absTime = GetTime();

		if (playPiano && absTime > keyCounter) {
			PlaySound(pianoSounds[keyCounter]);
			keyCounter += 1;
		}

		if (!gameOver && !gameWon) {
			if (IsKeyDown(KeyboardKey.KEY_LEFT) && paddle.position.x > 0) {
				paddle.position.x -= 800 * deltaTime;
			}

			if (IsKeyDown(KeyboardKey.KEY_RIGHT)
				    && paddle.position.x < screenWidth - paddle.size.x) {
				paddle.position.x += 800 * deltaTime;
			}

			if (IsKeyPressed(KeyboardKey.KEY_SPACE)) {
				foreach (const i; 0 .. maxBullets) {
					if (!bullets[i].active) {
						bullets[i].position = Vec2(paddle.position.x + paddle.size.x / 2, paddle.position.y);
						bullets[i].active = true;
						PlaySound(shootSound);
						break;
					}
				}
			}

			ball.position.x += ball.velocity.x * deltaTime;
			ball.position.y += ball.velocity.y * deltaTime;

			foreach (const i; 0 .. maxBullets) {
				if (bullets[i].active) {
					bullets[i].position.x += bullets[i].velocity.x * deltaTime;
					bullets[i].position.y += bullets[i].velocity.y * deltaTime;
					if (bullets[i].position.y < 0) {
						bullets[i].active = false;
					}
				}
			}

			if (ball.position.x <= ball.radius || ball.position.x >= screenWidth - ball.radius) {
				ball.velocity.x *= -1;
				PlaySound(wallSound);
			}

			if (ball.position.y <= ball.radius) {
				ball.velocity.y *= -1;
				PlaySound(wallSound);
			}

			if (ball.position.y + ball.radius >= paddle.position.y
				    && ball.position.y - ball.radius
					    <= paddle.position.y + paddle.size.y
				    && ball.position.x >= paddle.position.x
				    && ball.position.x <= paddle.position.x + paddle.size.x) {
				ball.velocity.y = -abs(ball.velocity.y);
				PlaySound(paddleSound);

				const float hitPos =
					(ball.position.x - paddle.position.x) / paddle.size.x;
				ball.velocity.x = 200 * (hitPos - 0.5f) * 2;
			}

			foreach (const i; 0 .. bricks.length) {
				if (!bricks[i].active)
					continue;

				if (ball.position.x + ball.radius >= bricks[i].position.x
					    && ball.position.x - ball.radius
						    <= bricks[i].position.x + bricks[i].size.x
					    && ball.position.y + ball.radius >= bricks[i].position.y
					    && ball.position.y - ball.radius
						    <= bricks[i].position.y + bricks[i].size.y) {
					bricks[i].active = false;
					ball.velocity.y *= -1;
					PlaySound(brickSound);
					break;
				}

				foreach (const j; 0 .. maxBullets) {
					if (!bullets[j].active)
						continue;

					if (bullets[j].position.x + bullets[j].radius >= bricks[i].position.x
						    && bullets[j].position.x - bullets[j].radius
							    <= bricks[i].position.x + bricks[i].size.x
						    && bullets[j].position.y + bullets[j].radius >= bricks[i].position.y
						    && bullets[j].position.y - bullets[j].radius
							    <= bricks[i].position.y + bricks[i].size.y) {
						bricks[i].active = false;
						bullets[j].active = false;
						PlaySound(brickSound);
						break;
					}
				}
			}

			bool allBricksDestroyed = true;
			foreach (const i; 0 .. bricks.length) {
				if (bricks[i].active) {
					allBricksDestroyed = false;
					break;
				}
			}

			gameWon = allBricksDestroyed;

			if (ball.position.y > screenHeight) {
				gameOver = true;
			}
		}

		if ((gameOver || gameWon) && IsKeyPressed(KeyboardKey.KEY_R)) {
			ball.position = Vec2(screenWidth / 2, screenHeight - 150);
			ball.velocity = Vec2(0, -800);

			paddle.position = Vec2(screenWidth / 2 - 60, screenHeight - 30);

			foreach (const i; 0 .. bricks.length) {
				bricks[i].active = true;
			}

			foreach (const i; 0 .. maxBullets) {
				bullets[i].active = false;
			}

			gameOver = false;
			gameWon = false;
		}

		BeginDrawing();
		scope(exit) EndDrawing();

		ClearBackground(Colors.BLACK);

		foreach (const i; 0 .. bricks.length) {
			if (bricks[i].active) {
				DrawRectangleV(bricks[i].position, bricks[i].size,
				               bricks[i].color);
			}
		}

		DrawRectangleV(paddle.position, paddle.size, paddle.color);

		DrawCircleV(ball.position, ball.radius, ball.color);

		foreach (const i; 0 .. maxBullets) {
			if (bullets[i].active) {
				DrawCircleV(bullets[i].position, bullets[i].radius, bullets[i].color);
			}
		}

		if (gameWon) {
			const text = "YOU WON! Press R to restart";
			const fontSize = 32;
			const textWidth = MeasureText(text.ptr, fontSize);
			DrawText(text.ptr, (screenWidth - textWidth) / 2, screenHeight / 2,
			         fontSize, Colors.GREEN);
		} else if (gameOver) {
			const text = "GAME OVER! Press R to restart";
			const fontSize = 32;
			const textWidth = MeasureText(text.ptr, fontSize);
			DrawText(text.ptr, (screenWidth - textWidth) / 2, screenHeight / 2,
			         fontSize, Colors.RED);
		} else {
			DrawText("LEFT/RIGHT arrows to move, SPACE to shoot".ptr, 10,
			         screenHeight - 25, 16, Colors.WHITE);
		}

		frameCounter += 1;
	}

	writeln("Ending Arkanoid game.");
}
