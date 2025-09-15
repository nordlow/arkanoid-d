module game;

import nxt.logger;
import nxt.geometry;
import nxt.interpolation;
import nxt.color;
import nxt.colors;
import nxt.algorithm.searching : endsWith;

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
	this(in ScreenSize ssz, const uint ballCount = 10, const Vel ballVelocity_ = Vel(200, -200)) @trusted {
		this.win = Window(ssz, "Arkanoid Clone");
		joystick = openDefaultJoystick();
		_rng = Random(unpredictableSeed());
		ballVelocity = ballVelocity_;
		scene = Scene(paddle: Paddle(shape: Rect(pos: Pos(ssz.width / 2 - 60, ssz.height - 30), size: Dim(150, 20)),
									 color: Colors.BLUE),
					  balls: makeBalls(ballCount, ballVelocity_, ssz.width, ssz.height),
					  bullets: makeBullets(30),
					  brickGrid: BrickGrid(nRows: 20, nCols: 30));
		scene.brickGrid.layout(ssz.width, ssz.height, Colors.DARKGREEN, Colors.DARKRED, Colors.DARKBLUE, Colors.DARKYELLOW);

		// load audio
		import nxt.path : FP = FilePath;
		brickFx = AudioFx(FP("sound/brick_hit.wav"), gain: 0.15f);
		paddleBounceFx = AudioFx(FP("sound/ball_gone.wav"));
		bulletShotFx = AudioFx(FP("sound/bullet_shot.wav"));
		adev = AudioDevice(brickFx.buffer.spec);
		// TODO: Remove then needed for this explicit call:
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
				case SDLK_SPACE:
					spacePressed = true;
					break;
				case SDLK_F11:
					win.fullscreen = !win.fullscreen;
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
	Window win;
	Scene scene;
	Vel ballVelocity;
	bool spacePressed, rPressed;
	bool quit, won, over, paused;
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
