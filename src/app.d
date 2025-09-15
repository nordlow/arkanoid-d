import core.time : Duration;
import core.stdc.stdio;
import core.stdc.math : fabs, sqrtf;

import std.random : uniform, Random, unpredictableSeed;
import std.math : abs, sqrt;
import std.string : fromStringz;

import nxt.algorithm.searching;
import nxt.logger;
import nxt.geometry;
import nxt.interpolation;
import nxt.color;
import nxt.colors;
import nxt.io;

import sdl;
import base;
import entities;
import music;
import waves;
import joystick;
import game;

@safe:

void main(string[] args) @trusted {
	setLogLevel(LogLevel.info);

	if (args.canFindAmong(["-v", "--verbose"]))
		SDL_SetLogPriorities(SDL_LogPriority.SDL_LOG_PRIORITY_TRACE);
	if (args.canFindAmong(["-h", "--help"]))
		ewriteln("Help");

	// initialize SDL
	static immutable SCREEN_WIDTH = 1920;
	static immutable SCREEN_HEIGHT = 1200;
	auto ssz = ScreenSize(SCREEN_WIDTH, SCREEN_HEIGHT);
	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
		warningf("SDL could not initialize! SDL_Error: %s", SDL_GetError().fromStringz());
		return;
	}
	scope(exit) { SDL_Quit(); }

	auto game = Game(ssz);

	// Note: Audio generation removed for SDL3 conversion - would need SDL_mixer or similar
	// Sound[] pianoSounds; // Audio system would need separate implementation

	ulong lastFrameTime = SDL_GetTicks();
	tracef("lastFrameTime: %s", lastFrameTime);

	for (uint frameCounter = 0; !game.quit; ++frameCounter) {
		const currentFrameTime = SDL_GetTicks();
		const deltaTime = (currentFrameTime - lastFrameTime) / 1000.0f;
		lastFrameTime = currentFrameTime;

		game.processEvents();

		// Get continuous key states
		const keyStates = SDL_GetKeyboardState(null);
		const bool leftHeld = keyStates[SDL_SCANCODE_LEFT] != 0;
		const bool rightHeld = keyStates[SDL_SCANCODE_RIGHT] != 0;

		if (!game.over && !game.won) {
			void moveLeft() {
				game.scene.paddle.moveLeft(deltaTime);
			}
			void moveRight() {
				game.scene.paddle.moveRight(deltaTime, ssz);
			}
			if (game.joystick.isValid) {
				while (const ev = game.joystick.tryNextEvent()) {
					tracef("Read %s heldButtons:", game.joystick.getHeldButtons);
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
			}
			if (leftHeld && game.scene.paddle.pos.x > 0)
				moveLeft();
			if (rightHeld && game.scene.paddle.pos.x < ssz.width - game.scene.paddle.size.x)
				moveRight();
			if (game.spacePressed) {
				foreach (ref bullet; game.scene.bullets) {
					if (bullet.active)
						continue;
					bullet.pos = Pos(game.scene.paddle.pos.x + game.scene.paddle.size.x / 2,
									  game.scene.paddle.pos.y);
					bullet.active = true;
					game.bulletShotFx.reput();
					break;
				}
			}

			// update balls
			game.scene.balls[].bounceAll();

			uint nBallsActive; // number of active balls
			foreach (ref ball; game.scene.balls) {
				if (!ball.active)
					continue;
				nBallsActive++;

				ball.pos += ball.vel * deltaTime;

				// handle bounce against left|right wall
				if (ball.pos.x <= ball.rad || ball.pos.x >= ssz.width - ball.rad)
					ball.vel.x *= -1; // flip x velocity. TODO: bounce sound
				// handle bounce against top wall
				if (ball.pos.y <= ball.rad)
					ball.vel.y *= -1; // flip y velocity. TODO: bounce sound

				// snap ball inside region
				enum EPS = 0.01f;
				if (ball.pos.x <= ball.rad) {
					ball.pos.x = ball.rad + EPS;
					ball.vel.x = abs(ball.vel.x); // ensure moving right
				}
				if (ball.pos.x >= ssz.width - ball.rad) {
					ball.pos.x = (ssz.width - ball.rad) - EPS;
					ball.vel.x = -abs(ball.vel.x); // ensure moving left
				}
				if (ball.pos.y <= ball.rad) {
					ball.pos.y = ball.rad + EPS;
					ball.vel.y = abs(ball.vel.y); // ensure moving down
				}

				// ball bounce against paddle
				if (ball.pos.y + ball.rad >= game.scene.paddle.pos.y
					&& ball.pos.y - ball.rad
					<= game.scene.paddle.pos.y + game.scene.paddle.size.y
					&& ball.pos.x >= game.scene.paddle.pos.x
					&& ball.pos.x <= game.scene.paddle.pos.x + game.scene.paddle.size.x) {
					ball.vel.y = -abs(ball.vel.y);
					const float hitPos = (ball.pos.x - game.scene.paddle.pos.x) / game.scene.paddle.size.x;
					ball.vel.x = 200 * (hitPos - 0.5f) * 2;
					game.paddleBounceFx.reput();
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
						game.brickFx.reput();
						ball.vel.y *= -1;
						break;
					}
				}
				if (ball.pos.y > ssz.height) {
					ball.active = false;
				}
			}
			tracef("Active: %s/%s", nBallsActive, game.scene.balls.length);

			game.animateBullets(deltaTime);

			// update logic for flashing bricks. TODO: Move to generic entity color animator
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

		if ((game.over || game.won) && game.rPressed) {
			foreach (ref ball; game.scene.balls) {
				ball.pos = Pos(ssz.width / 2 + (game.scene.balls.length - 1) * 20 - 20, ssz.height - 150);
				ball.vel = game.ballVelocity;
				ball.active = true;
			}
			game.scene.paddle.pos = Pos(ssz.width / 2 - 60, ssz.height - 30);
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

		game.scene.drawIn(game.win.rdr);

		if (game.won)
			printf("YOU WON! Press R to restart\n");
		else if (game.over)
			printf("GAME OVER! Press R to restart\n");
	}
}
