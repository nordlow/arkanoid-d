module game;

import nxt.logger;
import nxt.geometry;
import nxt.interpolation;
import nxt.color;
import nxt.colors;

import sdl3;
import aliases;
import renderer;
import entities;
import window;
import music;
import waves;
import joystick;

@safe:

nothrow struct Game {
	import std.random : Random, unpredictableSeed;
	@disable this(this);
	this(in ScreenSize ssz) @trusted {
		this.ssz = ssz;
		this.win = Window(ssz, "Arkanoid Clone", fullscreen: true);
		joystick = openDefaultJoystick();
		rng = Random(unpredictableSeed());
		scene = Scene(paddle: Paddle(shape: Rect(pos: Pos2(ssz.width / 2 - 60, ssz.height - 30), dim: Dim2(150, 20)),
									 color: Colors.BLUE),
					  balls: makeBalls(ballCount, ballVelocity, ssz.width, ssz.height),
					  bullets: makeBullets(30),
					  brickGrid: BrickGrid(nRows: 20, nCols: 30));
		scene.brickGrid.layout(ssz.width, ssz.height, Colors.DARKGREEN, Colors.DARKRED, Colors.DARKBLUE, Colors.DARKYELLOW);
	}
	void processEvents() @trusted {
		SDL_Event e;
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
					inFullscreen ^= true; // toggle
					if (!SDL_SetWindowFullscreen(win._ptr, inFullscreen))
						warning("Could not enter fullscreen! SDL_Error: %s", SDL_GetError());
					SDL_GetWindowSize(win._ptr, &ssz.width, &ssz.height);
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
	}
	ScreenSize ssz;
	Window win;
	static immutable ballCount = 50; // boll antal
	Scene scene;
	static immutable ballVelocity = Vel2(300, -300);
	static immutable soundSampleRate = 44100;
	bool leftPressed, rightPressed, spacePressed, rPressed;
	bool quit;
	Joystick joystick;
	Random rng;
	bool playMusic;
	bool inFullscreen;
	bool won, over;
}

struct Scene {
	@disable this(this);
	Paddle paddle;
	Ball[] balls;
	Bullet[] bullets;
	BrickGrid brickGrid;
	void drawIn(SDL_Renderer* rdr) @trusted {
		SDL_SetRenderDrawColor(rdr,
							   Colors.BLACK.r,
							   Colors.BLACK.g,
							   Colors.BLACK.b,
							   Colors.BLACK.a);
		SDL_RenderClear(rdr);
		brickGrid.drawIn(rdr);
		paddle.drawIn(rdr);
		balls.drawIn(rdr);
		bullets.drawIn(rdr);
		SDL_RenderPresent(rdr);
	}
}
