import core.time : Duration;
import std.stdio : stdout, stderr, writeln;
import std.algorithm : minElement, maxElement;
import std.random;
import std.math;

import raylib;

@safe:

alias Vec2 = Vector2;

alias SampleRate = uint;
alias FrameCount = uint;
alias Sample = short;

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

	Ball ball = {
		position: Vec2(screenWidth / 2, screenHeight - 150),
		velocity: Vec2(800, -800),
		radius: 10,
		color: Colors.WHITE
	};

	Paddle paddle = {
		position: Vec2(screenWidth / 2 - 60, screenHeight - 30),
		size: Vec2(250, 20),
		color: Colors.BLUE
	};

	const brickRows = 6;
	const brickCols = 10;
	const brickWidth = screenWidth / brickCols;
	const brickHeight = 30;
	Brick[brickRows * brickCols] bricks;

	for (int row = 0; row < brickRows; row++) {
		for (int col = 0; col < brickCols; col++) {
			int index = row * brickCols + col;
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

	const maxBullets = 10;
	Bullet[maxBullets] bullets;
	for (int i = 0; i < maxBullets; i++) {
		bullets[i].active = false;
		bullets[i].radius = 3;
		bullets[i].color = Colors.YELLOW;
		bullets[i].velocity = Vec2(0, -333);
	}

	bool gameWon = false;
	bool gameOver = false;

	while (!WindowShouldClose()) {
		const deltaTime = GetFrameTime();

		if (!gameOver && !gameWon) {
			if (IsKeyDown(KeyboardKey.KEY_LEFT) && paddle.position.x > 0) {
				paddle.position.x -= 800 * deltaTime;
			}

			if (IsKeyDown(KeyboardKey.KEY_RIGHT)
				    && paddle.position.x < screenWidth - paddle.size.x) {
				paddle.position.x += 800 * deltaTime;
			}

			if (IsKeyPressed(KeyboardKey.KEY_SPACE)) {
				for (int i = 0; i < maxBullets; i++) {
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

			for (int i = 0; i < maxBullets; i++) {
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

			for (int i = 0; i < bricks.length; i++) {
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

				for (int j = 0; j < maxBullets; j++) {
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
			for (int i = 0; i < bricks.length; i++) {
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
			ball.velocity = Vec2(200, -200);

			paddle.position = Vec2(screenWidth / 2 - 60, screenHeight - 30);

			for (int i = 0; i < bricks.length; i++) {
				bricks[i].active = true;
			}

			for (int i = 0; i < maxBullets; i++) {
				bullets[i].active = false;
			}

			gameOver = false;
			gameWon = false;
		}

		BeginDrawing();
		scope(exit) EndDrawing();

		ClearBackground(Colors.BLACK);

		for (int i = 0; i < bricks.length; i++) {
			if (bricks[i].active) {
				DrawRectangleV(bricks[i].position, bricks[i].size,
				               bricks[i].color);
			}
		}

		DrawRectangleV(paddle.position, paddle.size, paddle.color);

		DrawCircleV(ball.position, ball.radius, ball.color);

		for (int i = 0; i < maxBullets; i++) {
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
	}

	writeln("Ending Arkanoid game.");
}

Wave generateStaticWave(in float frequency, in float duration, in SampleRate sampleRate) pure nothrow {
	alias SS = Sample;
    const frameCount = cast(FrameCount)(sampleRate * duration);
    SS[] data = new SS[frameCount];
	foreach (const i; 0 .. frameCount)
        data[i] = cast(SS)(sin(2.0f * cast(float)std.math.PI * frequency * i / sampleRate) * SS.max);

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * SS.sizeof, channels: 1, data: &data[0]);
}

Wave generateBounceWave(in float startFreq, in float endFreq, in float duration, in SampleRate sampleRate) pure nothrow {
    alias SS = short;
    const frameCount = cast(FrameCount)(sampleRate * duration);
    SS[] data = new SS[frameCount];

    foreach (const i; 0 .. frameCount) {
        // Calculate the current frequency using an exponential sweep for a natural chirp effect
        const currentFreq = startFreq * pow(endFreq / startFreq, cast(float)i / frameCount);

        // Calculate the current amplitude using a decay envelope
        const amplitude = pow(1.0f - cast(float)i / frameCount, 2.0f); // Fast decay

        // Generate the sine wave sample
        const sample = sin(2.0f * cast(float)std.math.PI * currentFreq * i / sampleRate) * SS.max * amplitude;
        data[i] = cast(SS)(sample);
    }

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * SS.sizeof, channels: 1, data: &data[0]);
}

Wave generateBoingWave(in float startFreq, in float endFreq, in float duration, in SampleRate sampleRate) pure nothrow {
    alias SS = short;
    const frameCount = cast(FrameCount)(sampleRate * duration);
    SS[] data = new SS[frameCount];

    // Create a smooth frequency curve for the "boing"
    float frequencyCurve(float t) {
        // a combination of a sharp initial drop and a slower rise
        return startFreq * (1.0f - pow(t, 2.0f)) + endFreq * pow(t, 2.0f);
    }

    float amplitudeEnvelope(float t) {
        return pow(1 - t, 4.0f); // a very fast, percussive decay
    }

    foreach (const i; 0 .. frameCount) {
        const t = cast(float)i / frameCount;
        const currentFreq = frequencyCurve(t);
        const currentAmp = amplitudeEnvelope(t);
        const sample = sin(2.0f * cast(float)std.math.PI * currentFreq * i / sampleRate) * SS.max * currentAmp;
        data[i] = cast(SS)(sample);
    }

	debug data.showStats();
    return Wave(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * SS.sizeof, channels: 1, data: &data[0]);
}

Wave generateGlassBreakWave(scope ref Random rng, in float duration, in float amplitude, in SampleRate sampleRate) @safe {
    alias SS = short;
    const frameCount = cast(FrameCount)(sampleRate * duration);
    SS[] data = new SS[frameCount];

    foreach (const i; 0 .. frameCount) {
        const t = cast(float)i / frameCount;

        // Amplitude envelope for the initial "shatter"
        const shatterAmp = pow(1.0f - t, 8.0f); // Very fast, percussive decay for the noise
		const noiseSample = uniform(-1.0f, 1.0f, rng) * SS.max * shatterAmp;

        // Amplitude envelope for the "tinkle" effect
        const tinkleAmp = 0.5f * (1.0f - t); // Slower, linear decay for the high-frequency tone
        // Generate a high-frequency sine wave for the "tinkle"
        // This makes it sound less like static and more like breaking glass
        const tinkleSample = sin(2.0f * cast(float)std.math.PI * 10000.0f * i / sampleRate) * SS.max * tinkleAmp;

        const combinedSample = amplitude*(noiseSample * 0.7f + tinkleSample * 0.3f);

        data[i] = cast(SS)(combinedSample);
    }

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * SS.sizeof, channels: 1, data: &data[0]);
}

private void showStats(in Sample[] samples, in char[] funName = __FUNCTION__) {
	writeln(funName, ": [", samples.minElement, " ... " , samples.maxElement, "]");
}
