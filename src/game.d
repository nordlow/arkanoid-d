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
	this(in ScreenSize ssz, const uint ballCount = 10) @trusted {
		this.ssz = ssz;
		this.win = Window(ssz, "Arkanoid Clone");
		joystick = openDefaultJoystick();
		_rng = Random(unpredictableSeed());
		scene = Scene(paddle: Paddle(shape: Rect(pos: Pos(ssz.width / 2 - 60, ssz.height - 30), size: Dim(150, 20)),
									 color: Colors.BLUE),
					  balls: makeBalls(ballCount, ballVelocity, ssz.width, ssz.height),
					  bullets: makeBullets(30),
					  brickGrid: BrickGrid(nRows: 20, nCols: 30));
		scene.brickGrid.layout(ssz.width, ssz.height, Colors.DARKGREEN, Colors.DARKRED, Colors.DARKBLUE, Colors.DARKYELLOW);

		// load audio
		import nxt.path : FilePath;
		alias FP = FilePath;
		brickFx.buffer = loadWAV(FP("sound/brick_hit.wav"));
		paddleBounceFx.buffer = loadWAV(FP("sound/ball_gone.wav"));
		bulletShotFx.buffer = loadWAV(FP("sound/bullet_shot.wav"));

		brickFx.stream = AudioStream(brickFx.buffer.spec);
		paddleBounceFx.stream = AudioStream(paddleBounceFx.buffer.spec);
		bulletShotFx.stream = AudioStream(bulletShotFx.buffer.spec);

		adev = AudioDevice(brickFx.buffer.spec);
		adev.bind(brickFx.stream);
		adev.bind(paddleBounceFx.stream);
		adev.bind(bulletShotFx.stream);
	}
	~this() {}
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
				case SDLK_Q:
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
					win.fullscreen = inFullscreen;
					ssz = win.size;
					break;
				case SDLK_P:
					togglePause();
					break;
				case SDLK_R:
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
			adev.pause();
		else if (!paused)
			adev.resume();
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

	AudioFx brickFx, paddleBounceFx, bulletShotFx;
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
								game.brickFx.reput();
								bullet.active = false;
								break;
							}
		}
	}
}
