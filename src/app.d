import core.time : Duration;
import core.stdc.stdio;
import core.stdc.math : fabs, sqrtf;

import std.random : uniform, Random, unpredictableSeed;
import std.math : abs, sqrt;
import std.string : fromStringz;

import nxt.logger;
import nxt.joystick;

import sdl;
import base;
import entities;
import music;
import waves;
import game;

@safe:

void main(string[] args) @trusted {
	setLogLevel(LogLevel.info);

	import nxt.algorithm.searching : canFindAmong;
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

	auto lastFrameTimeMsecs = SDL_GetTicks(); // in msecs
	for (uint frameCounter = 0; !game.quit; ++frameCounter) {
		const currentFrameTimeMsecs = SDL_GetTicks(); // in msecs
		const deltaTime = (currentFrameTimeMsecs - lastFrameTimeMsecs) / 1000.0f;
		lastFrameTimeMsecs = currentFrameTimeMsecs;

		game.processEvents();

		const keyStates = SDL_GetKeyboardState(null);

		game.spacePressed = keyStates[SDL_SCANCODE_SPACE] != 0;

		if (!game.over && !game.won) {
			foreach (const pi, ref paddle; game.scene.paddles) {
				const leftHeld = keyStates[paddle.leftKey] != 0;
				const rightHeld = keyStates[paddle.rightKey] != 0;

				void moveLeft() => paddle.moveLeft(deltaTime, ssz);
				void moveRight() => paddle.moveRight(deltaTime, ssz);

				if (game.joystick.isValid) {
					while (const ev = game.joystick.tryNextEvent()) {
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

				if (leftHeld && paddle.pos.x > 0)
					moveLeft();

				if (rightHeld && paddle.pos.x < ssz.width - paddle.size.x)
					moveRight();

				if (game.spacePressed) {
					foreach (ref bullet; game.scene.bullets) {
						if (bullet.active)
							continue;
						bullet.pos = Pos(paddle.pos.x + paddle.size.x / 2,
										 paddle.pos.y);
						bullet.active = true;
						game.bulletShotFx.reput();
						break;
					}
				}
			}

			game.scene.balls[].bounceAll();

			foreach (ref ball; game.scene.balls) {
				if (!ball.active)
					continue;

				ball.update(deltaTime);

				// handle bounce against left|right wall
				if (ball.position.x <= ball.radius || ball.position.x >= ssz.width - ball.radius)
					ball.velocity.x *= -1; // flip x velocity. TODO: bounce sound
				// handle bounce against top wall
				if (ball.position.y <= ball.radius)
					ball.velocity.y *= -1; // flip y velocity. TODO: bounce sound

				// snap ball inside region
				enum EPS = 0.01f;
				if (ball.position.x <= ball.radius) {
					ball.position.x = ball.radius + EPS;
					ball.velocity.x = abs(ball.velocity.x); // ensure moving right
				}
				if (ball.position.x >= ssz.width - ball.radius) {
					ball.position.x = (ssz.width - ball.radius) - EPS;
					ball.velocity.x = -abs(ball.velocity.x); // ensure moving left
				}
				if (ball.position.y <= ball.radius) {
					ball.position.y = ball.radius + EPS;
					ball.velocity.y = abs(ball.velocity.y); // ensure moving down
				}

				// ball bounce against paddles
				foreach (ref paddle; game.scene.paddles) {
					if (ball.position.y + ball.radius >= paddle.pos.y // TODO: replace with distance between ball and paddles
					&& ball.position.y - ball.radius
					<= paddle.pos.y + paddle.size.y
					&& ball.position.x >= paddle.pos.x
					&& ball.position.x <= paddle.pos.x + paddle.size.x) {
						ball.velocity.y = -abs(ball.velocity.y);
						const float hitPos = (ball.position.x - paddle.pos.x) / paddle.size.x;
						ball.velocity.x = 200 * (hitPos - 0.5f) * 2;
						game.paddleBounceFx.reput();
					}
				}

				foreach (ref brick; game.scene.brickGrid[]) {
					if (!brick.active || brick.isFlashing)
						continue;
					if (ball.position.x + ball.radius >= brick.shape.pos.x
						&& ball.position.x - ball.radius
						<= brick.shape.pos.x + brick.shape.size.x
						&& ball.position.y + ball.radius >= brick.shape.pos.y
						&& ball.position.y - ball.radius
						<= brick.shape.pos.y + brick.shape.size.y) {
							brick.restartFlashing();
							game.brickFx.reput();
							ball.velocity.y *= -1;
							break;
						}
				}
				if (ball.position.y > ssz.height) {
					ball.active = false;
				}
			}

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
				ball.position = Pos(ssz.width / 2 + (game.scene.balls.length - 1) * 20 - 20, ssz.height - 150);
				ball.velocity = game.ballVelocity;
				ball.active = true;
			}
			foreach (ref paddle; game.scene.paddles)
				paddle.pos = Pos(ssz.width / 2 - 60, ssz.height - 30);
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
