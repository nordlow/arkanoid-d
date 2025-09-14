module game;

import nxt.logger;
import nxt.geometry;
import nxt.interpolation;
import nxt.color;
import nxt.colors;

import sdl;
import base;
import entities;
import music;
import waves;
import joystick;

@safe:

nothrow struct Game {
	import std.random : Random, unpredictableSeed;
	@disable this(this);
	this(in ScreenSize ssz, const uint ballCount = 1) @trusted {
		this.ssz = ssz;
		this.win = Window(ssz, "Arkanoid Clone", fullscreen: true);
		joystick = openDefaultJoystick();
		_rng = Random(unpredictableSeed());
		scene = Scene(paddle: Paddle(shape: Rect(pos: Pos(ssz.width / 2 - 60, ssz.height - 30), size: Dim(150, 20)),
									 color: Colors.BLUE),
					  balls: makeBalls(ballCount, ballVelocity, ssz.width, ssz.height),
					  bullets: makeBullets(30),
					  brickGrid: BrickGrid(nRows: 20, nCols: 30));
		scene.brickGrid.layout(ssz.width, ssz.height, Colors.DARKGREEN, Colors.DARKRED, Colors.DARKBLUE, Colors.DARKYELLOW);

		loadAudioFxs();

		adev = AudioDevice(brickFx.buffer.spec);
		brickFx.stream = AudioStream(brickFx.buffer.spec);
		adev.bind(brickFx.stream);
		brickFx.stream.put(brickFx.buffer);
	}
	void loadAudioFxs() {
		import nxt.path : FilePath;
		brickFx.buffer = AudioBuffer(FilePath("sound/brick_hit.wav"));
	}
	void processEvents() @trusted {
		SDL_Event e;
		while (SDL_PollEvent(&e)) {
			version(none) e.key.dbg;
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
				case SDLK_p:
					togglePause();
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
	void togglePause() {
		paused = !paused;
		if (paused)
			adev.stop();
		else if (!paused)
			adev.start();
	}
	ScreenSize ssz;
	Window win;
	Scene scene;
	static immutable ballVelocity = Vel(200, -200);
	bool leftPressed, rightPressed, spacePressed, rPressed;
	bool quit, won, over, paused;

	private bool inFullscreen;

	Joystick joystick;

	private AudioDevice adev;
	private Random _rng;
	version(none) static immutable soundSampleRate = 44100;

	AudioFx brickFx;
}

struct Scene {
	@disable this(this);
	Paddle paddle;
	Ball[] balls;
	Bullet[] bullets;
	BrickGrid brickGrid;
	void drawIn(scope ref Renderer rdr) @trusted {
		SDL_SetRenderDrawColor(rdr._ptr, Colors.BLACK.r, Colors.BLACK.g, Colors.BLACK.b,
							   Colors.BLACK.a);
		SDL_RenderClear(rdr._ptr);
		brickGrid.drawIn(rdr);
		paddle.drawIn(rdr);
		balls.drawIn(rdr);
		bullets.drawIn(rdr);
		SDL_RenderPresent(rdr._ptr);
	}
}

void animateBullets(scope ref Game game, float deltaTime) @trusted {
	foreach (ref bullet; game.scene.bullets) {
		if (!bullet.active)
			continue;
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
								game.brickFx.stream.clearAndPut(game.brickFx.buffer);
								bullet.active = false;
								break;
							}
		}
	}
}
