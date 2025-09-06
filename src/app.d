import core.time : Duration;
import core.stdc.stdio;
import core.stdc.math : fabs, sqrtf;

import std.random : uniform, Random, unpredictableSeed;
import std.math : abs, sqrt;

import nxt.logger;
import nxt.geometry;
import nxt.interpolation;
import nxt.color;
import nxt.colors;

import sdl3;
import aliases;
import renderer;
import entities;
import music;
import waves;
import joystick;

@safe:

void main() @trusted {
	setLogLevel(LogLevel.info);

	static immutable SCREEN_WIDTH = 800;
	static immutable SCREEN_HEIGHT = 600;

	auto ssz = ScreenSize(SCREEN_WIDTH, SCREEN_HEIGHT);

	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
		stderr.fprintf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
		return;
	}

	SDL_Window* window = SDL_CreateWindow("Arkanoid Clone", ssz.width, ssz.height, SDL_WINDOW_RESIZABLE);
	if (window is null) {
		stderr.fprintf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
		SDL_Quit();
		return;
	}

	// Get actual screen size after fullscreen
	SDL_GetWindowSize(window, &ssz.width, &ssz.height);

	SDL_Renderer* rndr = SDL_CreateRenderer(window, null);
	if (rndr is null) {
		stderr.fprintf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
		SDL_DestroyWindow(window);
		SDL_Quit();
		return;
	}

	if (!SDL_SetRenderVSync(rndr, 1))
		stderr.fprintf("Warning: VSync not supported\n");

	scope(exit) {
		SDL_DestroyRenderer(rndr);
		SDL_DestroyWindow(window);
		SDL_Quit();
	}

	auto game = Game(ssz);

	// Note: Audio generation removed for SDL3 conversion - would need SDL_mixer or similar
	// Sound[] pianoSounds; // Audio system would need separate implementation

	uint keyCounter;
	uint frameCounter;
	ulong lastTime = SDL_GetTicks();

	bool quit = false;
	while (!quit) {
		const currentTime = SDL_GetTicks();
		const deltaTime = (currentTime - lastTime) / 1000.0f;
		lastTime = currentTime;
		frameCounter++;

		// Handle events
		SDL_Event e;
		bool leftPressed = false, rightPressed = false, spacePressed = false, rPressed = false;

		while (SDL_PollEvent(&e)) {
			switch (e.type) {
			case SDL_EVENT_QUIT:
				quit = true;
				break;
			case SDL_EVENT_KEY_DOWN:
				if (false)
					warning(e.key.key);
				switch (e.key.key) {
				case SDLK_ESCAPE:
				case SDLK_q:
					quit = true;
					break;
				case SDLK_LEFT:
					leftPressed = true;
					break;
				case SDLK_RIGHT:
					rightPressed = true;
					break;
				case SDLK_SPACE:
					spacePressed = true;
					break;
				case SDLK_F11:
					if (!SDL_SetWindowFullscreen(window, true))
						stderr.fprintf("Could not enter fullscreen! SDL_Error: %s\n", SDL_GetError());
					break;
				case SDLK_r:
					rPressed = true;
					break;
				default:
					break;
				}
				break;
			default:
				break;
			}
		}

		// Get continuous key states
		const ubyte* keyStates = SDL_GetKeyboardState(null);
		const bool leftHeld = keyStates[SDL_SCANCODE_LEFT] != 0;
		const bool rightHeld = keyStates[SDL_SCANCODE_RIGHT] != 0;

		if (!game.over && !game.won) {
			void moveLeft() {
				if (game.scene.paddle.shape.pos.x > 0)
					game.scene.paddle.shape.pos.x -= 800 * deltaTime;
			}
			void moveRight() {
				if (game.scene.paddle.shape.pos.x < ssz.width - game.scene.paddle.shape.dim.x)
					game.scene.paddle.shape.pos.x += 800 * deltaTime;
			}
			while (const ev = game.joystick.tryNextEvent()) {
				info("Read ", ev, ", heldButtons:", game.joystick.getHeldButtons);
				if (ev.type == JoystickEvent.Type.axisMoved) {
					if (ev.buttonOrAxis == 0) {
						if (ev.axisValue < 0) moveLeft();
						else if (ev.axisValue > 0) moveRight();
					}
					if (ev.buttonOrAxis == 6) {
						if (ev.axisValue < 0) moveLeft();
						else if (ev.axisValue > 0) moveRight();
					}
				}
			}
			if (leftHeld && game.scene.paddle.shape.pos.x > 0)
				moveLeft();
			if (rightHeld && game.scene.paddle.shape.pos.x < ssz.width - game.scene.paddle.shape.dim.x)
				moveRight();
			if (spacePressed) {
				foreach (ref bullet; game.scene.bullets) {
					if (bullet.active)
						continue;
					bullet.pos = Pos2(game.scene.paddle.shape.pos.x + game.scene.paddle.shape.dim.x / 2, game.scene.paddle.shape.pos.y);
					bullet.active = true;
					// game.shootSound.PlaySound(); // Audio removed
					break;
				}
			}

			// update balls
			game.scene.balls[].bounceAll();
			foreach (ref ball; game.scene.balls) {
				if (!ball.active) continue;
				ball.pos += ball.vel * deltaTime;
				if (ball.pos.x <= ball.rad || ball.pos.x >= ssz.width - ball.rad) {
					ball.vel.x *= -1;
					// game.wallSound.PlaySound(); // Audio removed
				}
				if (ball.pos.y <= ball.rad) {
					ball.vel.y *= -1;
					// game.wallSound.PlaySound(); // Audio removed
				}
				if (ball.pos.y + ball.rad >= game.scene.paddle.shape.pos.y
					&& ball.pos.y - ball.rad
					<= game.scene.paddle.shape.pos.y + game.scene.paddle.shape.dim.y
					&& ball.pos.x >= game.scene.paddle.shape.pos.x
					&& ball.pos.x <= game.scene.paddle.shape.pos.x + game.scene.paddle.shape.dim.x) {
					ball.vel.y = -abs(ball.vel.y);
					// game.paddleSound.PlaySound(); // Audio removed
					const float hitPos = (ball.pos.x - game.scene.paddle.shape.pos.x) / game.scene.paddle.shape.dim.x;
					ball.vel.x = 200 * (hitPos - 0.5f) * 2;
				}
				foreach (ref brick; game.scene.brickGrid[]) {
					if (!brick.active || brick.isFlashing)
						continue;
					if (ball.pos.x + ball.rad >= brick.shape.pos.x
						&& ball.pos.x - ball.rad
						<= brick.shape.pos.x + brick.shape.size.x
						&& ball.pos.y + ball.rad >= brick.shape.pos.y
						&& ball.pos.y - ball.rad
						<= brick.shape.pos.y + brick.shape.size.y) {
						brick.restartFlashing();
						ball.vel.y *= -1;
						// PlaySound(game.brickSound); // Audio removed
						break;
					}
				}
				if (ball.pos.y > ssz.height) {
					ball.active = false;
				}
			}

			// update bullets
			foreach (ref bullet; game.scene.bullets) {
				if (bullet.active) {
					bullet.pos += bullet.vel * deltaTime;
					if (bullet.pos.y < 0)
						bullet.active = false;
					foreach (ref brick; game.scene.brickGrid[]) {
						if (!brick.active || brick.isFlashing)
							continue;
						if (bullet.pos.x + bullet.rad >= brick.shape.pos.x
							&& bullet.pos.x - bullet.rad
							<= brick.shape.pos.x + brick.shape.size.x
							&& bullet.pos.y + bullet.rad >= brick.shape.pos.y
							&& bullet.pos.y - bullet.rad
							<= brick.shape.pos.y + brick.shape.size.y) {
							brick.restartFlashing();
							bullet.active = false;
							// PlaySound(game.brickSound); // Audio removed
							break;
						}
					}
				}
			}

			// Update logic for flashing bricks
			foreach (ref brick; game.scene.brickGrid[]) {
				if (brick.isFlashing) {
					brick.flashTimer += deltaTime;
					if (brick.flashTimer >= Brick.FLASH_DURATION) {
						brick.active = false;
						brick.isFlashing = false;
					}
				}
			}

			bool allBricksDestroyed = true;
			foreach (const brick; game.scene.brickGrid[]) {
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

		if ((game.over || game.won) && rPressed) {
			foreach (ref ball; game.scene.balls) {
				ball.pos = Pos2(ssz.width / 2 + (game.scene.balls.length - 1) * 20 - 20, ssz.height - 150);
				ball.vel = game.ballVelocity;
				ball.active = true;
			}
			game.scene.paddle.shape.pos = Pos2(ssz.width / 2 - 60, ssz.height - 30);
			foreach (ref brick; game.scene.brickGrid[]) {
				brick.active = true;
				brick.isFlashing = false;
				brick.flashTimer = 0.0f;
			}
			foreach (ref bullet; game.scene.bullets)
				bullet.active = false;
			game.over = false;
			game.won = false;
		}

		// Rendering
		SDL_SetRenderDrawColor(rndr, Colors.BLACK.r, Colors.BLACK.g, Colors.BLACK.b, Colors.BLACK.a);
		SDL_RenderClear(rndr);
		game.scene.drawIn(rndr);
		if (game.won)
			printf("YOU WON! Press R to restart\n");
		else if (game.over)
			printf("GAME OVER! Press R to restart\n");
		SDL_RenderPresent(rndr);
	}
}

struct Game {
	@disable this(this);
	this(in ScreenSize ssz) @trusted {
		joystick = openDefaultJoystick();
		rng = Random(unpredictableSeed());
		scene = Scene(paddle: Paddle(shape: Rect(pos: Pos2(ssz.width / 2 - 60, ssz.height - 30), dim: Dim2(250, 20)),
									 color: Colors.BLUE),
					  balls: makeBalls(ballCount, ballVelocity, ssz.width, ssz.height),
					  bullets: makeBullets(30),
					  brickGrid: BrickGrid(nRows: 10, nCols: 15));
		scene.brickGrid.layout(ssz.width, ssz.height, Colors.DARKGREEN, Colors.DARKRED, Colors.DARKBLUE, Colors.DARKYELLOW);
	}
	static immutable ballCount = 10;
	Scene scene;
	static immutable ballVelocity = Vec2(100, -200);
	static immutable soundSampleRate = 44100;
	Joystick joystick;
	Random rng;
	bool playMusic;
	bool won, over;
}

struct Scene {
	@disable this(this);
	Paddle paddle;
	Ball[] balls;
	Bullet[] bullets;
	BrickGrid brickGrid;
	void drawIn(SDL_Renderer* rndr) @trusted {
		brickGrid.drawIn(rndr);
		paddle.drawIn(rndr);
		balls.drawIn(rndr);
		bullets.drawIn(rndr);
	}
}
