import core.time : Duration;
import core.stdc.stdio;
import core.stdc.math : fabs, sqrtf;

import std.random : uniform, Random, unpredictableSeed;
import std.math : abs, sqrt;

import nxt.geometry;
import nxt.color : Color = ColorRGBA, Colors = RaylibColors;

import entities;
import music;
import waves;
import joystick;

@safe:

enum SCREEN_WIDTH = 800;
enum SCREEN_HEIGHT = 600;

void main() @trusted {
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
        stderr.fprintf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return;
    }

    SDL_Window* window = SDL_CreateWindow("Arkanoid Clone", SCREEN_WIDTH, SCREEN_HEIGHT, SDL_WINDOW_RESIZABLE | SDL_WINDOW_FULLSCREEN_DESKTOP);
    if (window is null) {
        stderr.fprintf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_Quit();
        return;
    }

    // Get actual screen size after fullscreen
    int screenWidth, screenHeight;
    SDL_GetWindowSize(window, &screenWidth, &screenHeight);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, null);
    if (renderer is null) {
        stderr.fprintf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return;
    }

    if (!SDL_SetRenderVSync(renderer, 1))
        stderr.fprintf("Warning: VSync not supported\n");

    scope(exit) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
    }

    auto game = Game(screenWidth, screenHeight);

    // Note: Audio generation removed for SDL3 conversion - would need SDL_mixer or similar
    // Sound[] pianoSounds; // Audio system would need separate implementation

    game.scene.paddle = Paddle(pos: Pos2(screenWidth / 2 - 60, screenHeight - 30),
                         size: Dim2(250, 20),
                         color: Colors.BLUE);

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
                    switch (e.key.key) {
                        case SDLK_ESCAPE:
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
                if (game.scene.paddle.pos.x > 0)
                    game.scene.paddle.pos.x -= 800 * deltaTime;
            }
            void moveRight() {
                if (game.scene.paddle.pos.x < screenWidth - game.scene.paddle.size.x)
                    game.scene.paddle.pos.x += 800 * deltaTime;
            }

            // Handle joystick input (keeping original logic)
            while (const ev = game.joystick.tryNextEvent()) {
                import nxt.io : writeln;
                writeln("Read ", ev, ", heldButtons:", game.joystick.getHeldButtons);
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

            if (leftHeld && game.scene.paddle.pos.x > 0)
                moveLeft();

            if (rightHeld && game.scene.paddle.pos.x < screenWidth - game.scene.paddle.size.x)
                moveRight();

            if (spacePressed) {
                foreach (ref bullet; game.scene.bullets) {
                    if (bullet.active)
                        continue;
                    bullet.pos = Pos2(game.scene.paddle.pos.x + game.scene.paddle.size.x / 2, game.scene.paddle.pos.y);
                    bullet.active = true;
                    // game.shootSound.PlaySound(); // Audio removed
                    break;
                }
            }

            game.scene.balls[].bounceAll();

            foreach (ref ball; game.scene.balls) {
                if (!ball.active) continue;
                ball.pos += ball.vel * deltaTime;
                if (ball.pos.x <= ball.rad || ball.pos.x >= screenWidth - ball.rad) {
                    ball.vel.x *= -1;
                    // game.wallSound.PlaySound(); // Audio removed
                }
                if (ball.pos.y <= ball.rad) {
                    ball.vel.y *= -1;
                    // game.wallSound.PlaySound(); // Audio removed
                }
                if (ball.pos.y + ball.rad >= game.scene.paddle.pos.y
                    && ball.pos.y - ball.rad
                    <= game.scene.paddle.pos.y + game.scene.paddle.size.y
                    && ball.pos.x >= game.scene.paddle.pos.x
                    && ball.pos.x <= game.scene.paddle.pos.x + game.scene.paddle.size.x) {
                    ball.vel.y = -abs(ball.vel.y);
                    // game.paddleSound.PlaySound(); // Audio removed
                    const float hitPos = (ball.pos.x - game.scene.paddle.pos.x) / game.scene.paddle.size.x;
                    ball.vel.x = 200 * (hitPos - 0.5f) * 2;
                }
                foreach (ref brick; game.scene.brickGrid.bricks) {
                    if (!brick.active || brick.isFlashing)
                        continue;
                    if (ball.pos.x + ball.rad >= brick.pos.x
                        && ball.pos.x - ball.rad
                        <= brick.pos.x + brick.size.x
                        && ball.pos.y + ball.rad >= brick.pos.y
                        && ball.pos.y - ball.rad
                        <= brick.pos.y + brick.size.y) {
                        brick.restartFlashing();
                        ball.vel.y *= -1;
                        // PlaySound(game.brickSound); // Audio removed
                        break;
                    }
                }
                if (ball.pos.y > screenHeight) {
                    ball.active = false;
                }
            }
            foreach (ref bullet; game.scene.bullets) {
                if (bullet.active) {
                    bullet.pos += bullet.vel * deltaTime;
                    if (bullet.pos.y < 0)
                        bullet.active = false;
                    foreach (ref brick; game.scene.brickGrid.bricks) {
                        if (!brick.active || brick.isFlashing)
                            continue;
                        if (bullet.pos.x + bullet.rad >= brick.pos.x
                            && bullet.pos.x - bullet.rad
                            <= brick.pos.x + brick.size.x
                            && bullet.pos.y + bullet.rad >= brick.pos.y
                            && bullet.pos.y - bullet.rad
                            <= brick.pos.y + brick.size.y) {
                            brick.restartFlashing();
                            bullet.active = false;
                            // PlaySound(game.brickSound); // Audio removed
                            break;
                        }
                    }
                }
            }

            // Update logic for flashing bricks
            foreach (ref brick; game.scene.brickGrid.bricks) {
                if (brick.isFlashing) {
                    brick.flashTimer += deltaTime;
                    if (brick.flashTimer >= Brick.FLASH_DURATION) {
                        brick.active = false;
                        brick.isFlashing = false;
                    }
                }
            }

            bool allBricksDestroyed = true;
            foreach (const brick; game.scene.brickGrid.bricks) {
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
                ball.pos = Pos2(screenWidth / 2 + (game.scene.balls.length - 1) * 20 - 20, screenHeight - 150);
                ball.vel = game.ballVelocity;
                ball.active = true;
            }
            game.scene.paddle.pos = Pos2(screenWidth / 2 - 60, screenHeight - 30);
            foreach (ref brick; game.scene.brickGrid.bricks) {
                brick.active = true;
                brick.isFlashing = false;
                brick.flashTimer = 0.0f;
                if (brick.pos.y + brick.size.y < 250 + 2 * 30)
                    brick.color = Colors.RED;
                else if (brick.pos.y + brick.size.y < 250 + 4 * 30)
                    brick.color = Colors.YELLOW;
                else
                    brick.color = Colors.GREEN;
            }
            foreach (ref bullet; game.scene.bullets)
                bullet.active = false;
            game.over = false;
            game.won = false;
        }

        // Rendering
        SDL_SetRenderDrawColor(renderer, Colors.BLACK.r, Colors.BLACK.g, Colors.BLACK.b, Colors.BLACK.a);
        SDL_RenderClear(renderer);
        game.scene.draw(renderer);
        if (game.won)
            printf("YOU WON! Press R to restart\n");
		else if (game.over)
            printf("GAME OVER! Press R to restart\n");
        SDL_RenderPresent(renderer);
    }
}

struct Game {
    @disable this(this);

    this(in uint screenWidth, in uint screenHeight) @trusted {
        joystick = openDefaultJoystick();
        rng = Random(unpredictableSeed());
        scene = Scene(balls: makeBalls(ballCount, ballVelocity, screenWidth, screenHeight),
                      bullets: makeBullets(30),
                      brickGrid: BrickGrid(rows: 10, cols: 10));
        scene.brickGrid.bricks.layoutBricks(screenWidth, screenHeight, scene.brickGrid.rows, scene.brickGrid.cols);

        // Audio generation removed for SDL3 conversion
    }

    Joystick joystick;

    static immutable ballCount = 10;
    const ballVelocity = Vec2(100, -200);

    Scene scene;

    static immutable soundSampleRate = 44100;
    Random rng;
    // Sound objects removed for SDL3 conversion
    bool playMusic;

    bool won;
    bool over;
}

struct Scene {
    @disable this(this);
    Paddle paddle;
    Ball[] balls;
    Bullet[] bullets;
    BrickGrid brickGrid;
    void draw(SDL_Renderer* renderer) @trusted {
        brickGrid.draw(renderer);
        paddle.draw(renderer);
        balls.draw(renderer);
        bullets.draw(renderer);
    }
}

void layoutBricks(scope Brick[] bricks, in int screenWidth, in int screenHeight, in int brickRows, in int brickCols) pure nothrow @nogc {
    const brickWidth = screenWidth / brickCols;
    const brickHeight = 30;
    foreach (const row; 0 .. brickRows) {
        foreach (const col; 0 .. brickCols) {
            const index = row * brickCols + col;
            bricks[index] = Brick(pos: Pos2(col * brickWidth, row * brickHeight + 250),
                                  size: Dim2(brickWidth - 2, brickHeight - 2),
                                  Colors.RED, true);
            if (row < 2)
                bricks[index].color = Colors.RED;
            else if (row < 4)
                bricks[index].color = Colors.YELLOW;
            else
                bricks[index].color = Colors.GREEN;
        }
    }
}

float dot(in Vec2 v1, in Vec2 v2) pure nothrow @nogc {
    version(D_Coverage) {} else pragma(inline, true);
    return v1.x*v2.x + v1.y*v2.y;
}

float lengthSquared(in Vec2 v) pure nothrow @nogc {
    version(D_Coverage) {} else pragma(inline, true);
    return v.x*v.x + v.y*v.y;
}

float length(in Vec2 v) pure nothrow @nogc {
    version(D_Coverage) {} else pragma(inline, true);
    return v.lengthSquared.sqrt;
}

Vec2 normalized(in Vec2 v) pure nothrow @nogc {
    version(D_Coverage) {} else pragma(inline, true);
    const l = v.length;
    if (l == 0)
        return Vec2(0, 0);
    return v / l;
}

struct Ball {
    Pos2 pos;
    float rad;
    Vec2 vel;
    Color color;
    bool active;

    void draw(SDL_Renderer* renderer) const nothrow @trusted {
        if (active) {
            SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
            // Draw circle using filled rectangles (simple approximation)
            drawFilledCircle(renderer, cast(int)pos.x, cast(int)pos.y, cast(int)rad);
        }
    }
}

Ball[] makeBalls(uint count, Vec2 ballVelocity, uint screenWidth, uint screenHeight) {
    typeof(return) ret;
    ret.length = count;
    foreach (const i, ref ball; ret)
        ball = Ball(pos: Pos2(screenWidth / 2 + i * 20 - 20, screenHeight - 150),
                    vel: ballVelocity,
                    rad: 15,
                    color: Colors.GRAY,
                    active: true);
    return ret;
}

void bounceAll(ref Ball[] balls) pure nothrow @nogc {
    foreach (i, ref Ball ballA; balls) {
        foreach (ref Ball ballB; balls[i + 1 .. $]) {
            if (!ballA.active || !ballB.active)
                continue;

            const delta = ballB.pos - ballA.pos;
            const distSqr = delta.lengthSquared;
            const combinedRadii = ballA.rad + ballB.rad;
            const combinedRadiiSquared = combinedRadii * combinedRadii;
            const bool isOverlap = distSqr < combinedRadiiSquared;
            if (isOverlap) {
                const dist = distSqr.sqrt;
                const overlap = combinedRadii - dist;
                const normal = delta.normalized;

                ballA.pos -= normal * (overlap / 2.0f);
                ballB.pos += normal * (overlap / 2.0f);

                const tangent = Vec2(-normal.y, normal.x);

                const v1n = dot(ballA.vel, normal);
                const v1t = dot(ballA.vel, tangent);
                const v2n = dot(ballB.vel, normal);
                const v2t = dot(ballB.vel, tangent);

                const v1n_prime = v2n;
                const v2n_prime = v1n;

                ballA.vel = (normal * v1n_prime) + (tangent * v1t);
                ballB.vel = (normal * v2n_prime) + (tangent * v2t);
            }
        }
    }
}

// Helper function to draw filled circle using SDL rectangles
void drawFilledCircle(SDL_Renderer* renderer, int centerX, int centerY, int radius) nothrow @trusted {
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            if (x*x + y*y <= radius*radius) {
                const rect = SDL_FRect(centerX + x, centerY + y, 1, 1);
                SDL_RenderFillRect(renderer, &rect);
            }
        }
    }
}

// SDL3 extern(C) function declarations
extern(C) nothrow @nogc:

struct SDL_Window;
struct SDL_Renderer;

enum uint SDL_INIT_VIDEO = 0x00000020;
enum uint SDL_INIT_AUDIO = 0x00000010;
enum uint SDL_WINDOW_RESIZABLE = 0x00000020;
enum uint SDL_WINDOW_FULLSCREEN_DESKTOP = 0x00001001;

enum uint SDL_EVENT_QUIT = 0x100;
enum uint SDL_EVENT_KEY_DOWN = 0x300;
enum uint SDL_EVENT_WINDOW_RESIZED = 0x203;

enum uint SDLK_ESCAPE = 27;
enum uint SDLK_SPACE = 32;
enum uint SDLK_LEFT = 1073741904;
enum uint SDLK_RIGHT = 1073741903;
enum uint SDLK_r = 114;

enum uint SDL_SCANCODE_LEFT = 80;
enum uint SDL_SCANCODE_RIGHT = 79;

struct SDL_Color {
    ubyte r, g, b, a;
}

struct SDL_FRect {
    float x, y, w, h;
}

struct SDL_KeyboardEvent {
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    ubyte state;
    ubyte repeat;
    ubyte padding2;
    ubyte padding3;
    uint key;
    uint mod;
    ushort raw;
    ushort unused;
}

struct SDL_WindowEvent {
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    uint event;
    int data1;
    int data2;
}

union SDL_Event {
    uint type;
    SDL_KeyboardEvent key;
    SDL_WindowEvent window;
    ubyte[128] padding;
}

bool SDL_Init(uint flags);
void SDL_Quit();
SDL_Window* SDL_CreateWindow(const char* title, int w, int h, uint flags);
void SDL_DestroyWindow(SDL_Window* window);
SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, const char* name);
void SDL_DestroyRenderer(SDL_Renderer* renderer);
bool SDL_PollEvent(SDL_Event* event);
int SDL_SetRenderDrawColor(SDL_Renderer* renderer, ubyte r, ubyte g, ubyte b, ubyte a);
int SDL_RenderClear(SDL_Renderer* renderer);
int SDL_RenderFillRect(SDL_Renderer* renderer, const SDL_FRect* rect);
int SDL_RenderRect(SDL_Renderer* renderer, const SDL_FRect* rect);
int SDL_RenderPresent(SDL_Renderer* renderer);
bool SDL_SetRenderVSync(SDL_Renderer* renderer, int vsync);
ulong SDL_GetTicks();
const(char)* SDL_GetError();
void SDL_GetWindowSize(SDL_Window* window, int* w, int* h);
const(ubyte)* SDL_GetKeyboardState(int* numkeys);
