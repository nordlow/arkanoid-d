module game;

import nxt.logger;
import nxt.geometry;
import nxt.interpolation;
import nxt.color;
import nxt.colors;
import nxt.algorithm.searching : endsWith;
import nxt.joystick;

import sdl;
import base;
import entities;
import nxt.music;
import waves;

@safe:

nothrow struct Game {
	import std.random : Random, unpredictableSeed;

	@disable this(this);

	this(in ScreenSize ssz) @trusted {
		this.win = Window(ssz, "Arkanoid Clone");
		version(none) joystick = openDefaultJoystick();
		_rng = Random(unpredictableSeed());
		const paddleCount = 2;
		const ballCount = 10;
		ballVelocity = Vel(200, 200);
		scene = Scene(paddles: makePaddles(paddleCount,
										   shape: Rect(pos: Pos(ssz.width / 2 - 60, ssz.height - 30), size: Dim(150, 20)),
										   color: Colors.BLUE, ssz.width, ssz.height),
					  balls: makeBalls(ballCount, ballVelocity, ssz.width, ssz.height),
					  bullets: makeBullets(30),
					  brickGrid: BrickGrid(nRows: 20, nCols: 30));
		scene.brickGrid.layout(ssz.width, ssz.height, Colors.DARKGREEN, Colors.DARKRED, Colors.DARKBLUE, Colors.DARKYELLOW);

		// load audio
		import nxt.path : FP = FilePath;
		brickFx = AudioFx(FP("sound/brick_hit.wav"), gain: 0.15f);
		paddleBounceFx = AudioFx(FP("sound/ball_gone.wav"));
		bulletShotFx = AudioFx(FP("sound/bullet_shot.wav"));
		adev = AudioDevice(brickFx.buffer.spec);
		if (adev) {
			// TODO: Remove then needed for this explicit call:
			adev.bind(brickFx.stream);
			adev.bind(paddleBounceFx.stream);
			adev.bind(bulletShotFx.stream);

		}
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
	AudioDevice adev;
	private Random _rng;
	version(none) static immutable soundSampleRate = 44100;
	AudioFx brickFx, paddleBounceFx, bulletShotFx;
}

struct Scene {
	@disable this(this);
	Paddle[] paddles;
	Ball[] balls;
	Bullet[] bullets;
	BrickGrid brickGrid;
	void drawIn(scope ref Renderer rdr) @trusted {
		rdr.drawColor = Colors.BLACK;
		rdr.clear();
		brickGrid.drawIn(rdr);
		paddles.drawIn(rdr);
		balls.drawIn(rdr);
		bullets.drawIn(rdr);
		rdr.present();
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
								if(game.adev) game.brickFx.reput();
								bullet.active = false;
								break;
							}
		}
	}
}
