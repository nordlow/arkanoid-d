module sdl;

public import std.string : fromStringz, toStringz;
public import nxt.color;
public import nxt.effects;
public import nxt.logger;
public import sdl.SDL;
public import sdl.log;
public import sdl.window;
public import sdl.render;
public import sdl.audio;
public import sdl.joystick;
public import sdl.pixels;

struct ScreenSize { int width; int height; }
alias RGBA = ColorRGBA;
alias HSV = ColorHSV;

nothrow @nogc:

extern(C):

// Window flags
enum uint SDL_WINDOW_RESIZABLE = 0x00000020;

// Core SDL functions
int SDL_Init(uint flags);
void SDL_Quit();
void SDL_QuitSubSystem(uint flags);
const(char)* SDL_GetError();
ulong SDL_GetTicks();

// Window functions
SDL_Window* SDL_CreateWindow(const char* title, int w, int h, uint flags);
void SDL_GetWindowSize(SDL_Window* window, int* w, int* h);
bool SDL_SetWindowFullscreen(SDL_Window* window, bool fullscreen);

// Renderer functions - CORRECTED based on SDL3 documentation
SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, const char* name);
void SDL_DestroyRenderer(SDL_Renderer* renderer);

bool SDL_GetRenderDrawColor(SDL_Renderer *renderer, Uint8 *r, Uint8 *g, Uint8 *b, Uint8 *a);
int SDL_SetRenderDrawColor(SDL_Renderer* renderer, ubyte r, ubyte g, ubyte b, ubyte a);
int SDL_RenderFillRect(SDL_Renderer* renderer, const SDL_FRect* rect);
int SDL_RenderRect(SDL_Renderer* renderer, const SDL_FRect* rect);

bool SDL_RenderClear(SDL_Renderer *renderer);
bool SDL_RenderPresent(SDL_Renderer* renderer);
bool SDL_SetRenderVSync(SDL_Renderer* renderer, int vsync);

// Texture
bool SDL_RenderTexture(SDL_Renderer* renderer, SDL_Texture* texture, const SDL_FRect* srcrect, const SDL_FRect* dstrect);
SDL_Texture* SDL_CreateTextureFromSurface(SDL_Renderer* renderer, SDL_Surface* surface);
void SDL_DestroyTexture(SDL_Texture* texture);

SDL_Surface* SDL_LoadBMP(const char* file);
void SDL_DestroySurface(SDL_Surface* surface);

const(ubyte)* SDL_GetKeyboardState(int* numkeys);
