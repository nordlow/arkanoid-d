import core.time : Duration;
import std.stdio;
import std.algorithm : minElement, maxElement, sum;
import std.numeric;
import std.random : uniform, Random, unpredictableSeed;
import std.math;

import raylib;
import music;

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
	// auto shootSound = generatePianoTone(200.0f, 1.0f, 1.0f, sampleRate).LoadSoundFromWave();
	// auto shootSound = rng.generateScreamWave(0.3f, sampleRate).LoadSoundFromWave();

	const pianoKeys = __traits(allMembers, Key);
	Sound[] pianoSounds;
	pianoSounds.reserve(pianoKeys.length);
	foreach (const i, const key; pianoKeys) {
		const f = cast(float)__traits(getMember, Key, key);
		// pianoSounds ~= generatePianoTone(f, 1.0f, 1.0f, sampleRate).LoadSoundFromWave();;
	}

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
		if (absTime > keyCounter) {
			// PlaySound(pianoSounds[keyCounter]);
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
			ball.velocity = Vec2(200, -200);

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

Wave generateStaticWave(in float frequency, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];
	foreach (const i; 0 .. frameCount)
        data[i] = cast(Sample)(sin(2.0f * cast(float)std.math.PI * frequency * i / sampleRate) * Sample.max);

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateBounceWave(in float startFreq, in float endFreq, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];
    foreach (const i; 0 .. frameCount) {
        // calculate the current frequency using an exponential sweep for a natural chirp effect
        const currentFreq = startFreq * pow(endFreq / startFreq, cast(float)i / frameCount);
        const amplitude = pow(1.0f - cast(float)i / frameCount, 2.0f); // fast amplitude envelope decay
        const sample = sin(2.0f * cast(float)std.math.PI * currentFreq * i / sampleRate) * Sample.max * amplitude;
        data[i] = cast(Sample)(sample);
    }

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateBoingWave(in float startFreq, in float endFreq, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];

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
        const sample = sin(2.0f * cast(float)std.math.PI * currentFreq * i / sampleRate) * Sample.max * currentAmp;
        data[i] = cast(Sample)(sample);
    }

	debug data.showStats();
    return Wave(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateGlassBreakWave(scope ref Random rng, in float duration, in float amplitude, in SampleRate sampleRate) @safe {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];

    foreach (const i; 0 .. frameCount) {
        const t = cast(float)i / frameCount;

        // Amplitude envelope for the initial "shatter"
        const shatterAmp = pow(1.0f - t, 8.0f); // Very fast, percussive decay for the noise
		const noiseSample = uniform(-1.0f, 1.0f, rng) * Sample.max * shatterAmp;

        // Amplitude envelope for the "tinkle" effect
        const tinkleAmp = 0.5f * (1.0f - t); // Slower, linear decay for the high-frequency tone
        // Generate a high-frequency sine wave for the "tinkle"
        // This makes it sound less like static and more like breaking glass
        const tinkleSample = sin(2.0f * cast(float)std.math.PI * 10000.0f * i / sampleRate) * Sample.max * tinkleAmp;

        const combinedSample = amplitude*(noiseSample * 0.7f + tinkleSample * 0.3f);

        data[i] = cast(Sample)(combinedSample);
    }

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateScreamWave(scope ref Random rng, in float duration, in SampleRate sampleRate) @safe {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];

    // Define a frequency range for the scream
    const float startFreq = 200.0f; // Lower frequency for the start
    const float endFreq = 2000.0f; // High frequency for the peak of the scream

    // Define the overall amplitude envelope
    float amplitudeEnvelope(float t) {
        // A sharp rise and a slower, noisy decay
        // This simulates the vocal cords tightening and then relaxing
        return pow(t, 0.5f) * pow(1.0f - t, 2.0f);
    }

    // Define a frequency sweep that rises quickly and then levels off
    float frequencySweep(float t) {
        return startFreq + (endFreq - startFreq) * pow(t, 1.0f/3.0f);
    }

    foreach (const i; 0 .. frameCount) {
        const t = cast(float)i / frameCount;

        // Combine a sine wave with the frequency sweep
        const sineWave = sin(2.0f * cast(float)std.math.PI * frequencySweep(t) * i / sampleRate);

        // Add random high-frequency noise to simulate vocal "grit"
        const noise = uniform(-1.0f, 1.0f, rng) * 0.5f;

        // Combine the sine wave and noise, then apply the overall amplitude envelope
        const combinedSample = (sineWave * 0.7f + noise * 0.3f) * amplitudeEnvelope(t);

        // Scale and cast to the sample type
        data[i] = cast(Sample)(combinedSample * Sample.max);
    }

    debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

version(none)
Wave generatePianoTone(in float frequency, in float _amplitude, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];

    // More realistic ADSR envelope parameters for grand piano
    const float attackTime = 0.005f;  // Very sharp attack (5ms)
    const float decayTime = 0.3f;     // Longer decay for piano character
    const float sustainLevel = 0.2f;  // Lower sustain (piano notes decay significantly)
    const float releaseTime = duration * 0.6f; // Longer, natural release

    // More realistic harmonic content based on piano string physics
    // Piano harmonics are not perfect integer multiples due to string stiffness
    immutable float[8] harmonicAmplitudes = [
        1.0,    // Fundamental
        0.6,    // 2nd harmonic (strong in piano)
        0.25,   // 3rd harmonic
        0.15,   // 4th harmonic
        0.08,   // 5th harmonic
        0.05,   // 6th harmonic
        0.03,   // 7th harmonic
        0.02    // 8th harmonic
    ];

    // Slightly inharmonic frequencies (piano string stiffness effect)
    const float inharmonicity = 0.0001f * (frequency / 440.0f); // Higher for higher frequencies
    float[8] harmonicFrequencies;
    foreach (j; 0 .. harmonicFrequencies.length) {
        const float n = j + 1; // Harmonic number
        harmonicFrequencies[j] = frequency * n * (1.0f + inharmonicity * n * n);
    }

    // Frequency-dependent amplitude and timbre adjustments
    const float bassBoost = frequency < 200.0f ? 2.0f : 1.0f;
    const float midBoost = (frequency >= 200.0f && frequency <= 2000.0f) ? 1.2f : 1.0f;
    const float trebleRolloff = frequency > 2000.0f ? 0.7f : 1.0f;
    const float amplitudeBoost = bassBoost * midBoost * trebleRolloff;

    foreach (const i; 0 .. frameCount) {
        const float t = cast(float)i / sampleRate;
        float amplitude = 0.0;

        // More realistic ADSR envelope with exponential curves
        if (t < attackTime) {
            // Sharp attack with slight curve
            const float attackProgress = t / attackTime;
            amplitude = attackProgress * attackProgress; // Quadratic for sharper attack
        } else if (t < attackTime + decayTime) {
            // Exponential decay
            const float decayProgress = (t - attackTime) / decayTime;
            amplitude = 1.0f - decayProgress * decayProgress * (1.0f - sustainLevel);
        } else if (t < duration - releaseTime) {
            // Sustain with slight natural decay
            const float sustainProgress = (t - attackTime - decayTime) / (duration - releaseTime - attackTime - decayTime);
            amplitude = sustainLevel * (1.0f - sustainProgress * 0.3f); // Gradual decay during sustain
        } else {
            // Exponential release
            const float releaseProgress = (t - (duration - releaseTime)) / releaseTime;
            const float currentSustain = sustainLevel * (1.0f - 0.3f); // Account for sustain decay
            amplitude = currentSustain * exp(-releaseProgress * 3.0f); // Exponential decay
        }

        // Generate waveform with realistic harmonics
        float sampleValue = 0.0;
        foreach (j; 0 .. harmonicAmplitudes.length) {
            // Add slight phase modulation for more organic sound
            const float phaseModulation = sin(2.0 * std.math.PI * frequency * 0.1f * t) * 0.001f;
            const float phase = 2.0 * std.math.PI * harmonicFrequencies[j] * t + phaseModulation;

            // Frequency-dependent harmonic decay over time
            const float harmonicDecay = 1.0f - (t / duration) * (j * 0.1f);
            sampleValue += harmonicAmplitudes[j] * harmonicDecay * sin(phase);
        }

        // Add subtle noise for realism (hammer noise, string resonance)
        const float noiseLevel = 0.002f * amplitude;
        const float noise = (cast(float)((i * 1103515245 + 12345) % 32768) / 16384.0f - 1.0f) * noiseLevel;

        // Apply amplitude envelope and frequency-based adjustments
        const float finalAmplitude = amplitude * amplitudeBoost * _amplitude;
        data[i] = cast(Sample)((sampleValue + noise) * finalAmplitude * Sample.max * 0.3f);
    }

    debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

private void showStats(in Sample[] samples, in char[] funName = __FUNCTION__) {
	writeln(funName, ": [", samples.minElement, " ... " , samples.maxElement, "]");
}
