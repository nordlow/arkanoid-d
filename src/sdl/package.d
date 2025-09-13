module sdl;

public import sdl.log;
public import nxt.color;

/+ TODO: public import sdl.SDL; +/

alias RGBA = ColorRGBA;
alias HSV = ColorHSV;

nothrow @nogc:

struct SDL_Point { int x, y; }
struct SDL_FPoint { float x, y; }
struct SDL_Color { ubyte r, g, b, a; }
struct SDL_FColor { float r, g, b, a; }
struct SDL_FRect { float x, y, w, h; }
struct SDL_Rect { int x, y, w, h; }
struct ScreenSize { int width; int height; }

struct SDL_Vertex {
	SDL_FPoint position; /**< Vertex position, in SDL_Renderer coordinates	*/
	SDL_FColor color; /**< Vertex color */
	SDL_FPoint tex_coord; /**< Normalized texture coordinates, if needed */
}

int SDL_SetRenderDrawColor(SDL_Renderer* renderer, in RGBA color) {
	version(D_Coverage) {} else pragma(inline, true);
	return SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
}

extern(C):

// Forward declarations
struct SDL_Window;
struct SDL_Renderer;
struct SDL_Texture;
struct SDL_Surface;

// Initialization flags
enum uint SDL_INIT_VIDEO = 0x00000020;
enum uint SDL_INIT_AUDIO = 0x00000010;

// Window flags
enum uint SDL_WINDOW_RESIZABLE = 0x00000020;
enum uint SDL_WINDOW_FULLSCREEN_DESKTOP = 0x00001001;

// Event types (these values may need verification against actual headers)
enum uint SDL_EVENT_QUIT = 0x100;
enum uint SDL_EVENT_KEY_DOWN = 0x300;
enum uint SDL_EVENT_WINDOW_RESIZED = 0x203;

// Key codes
version(linux) {
	enum uint SDLK_ESCAPE = 41;
	enum uint SDLK_SPACE = 44;
	enum uint SDLK_LEFT = 1073741904;
	enum uint SDLK_RIGHT = 1073741903;
	enum uint SDLK_F11 = 68;
	enum uint SDLK_q = 20;
	enum uint SDLK_r = 114;
}

// Scan codes
enum uint SDL_SCANCODE_LEFT = 80;
enum uint SDL_SCANCODE_RIGHT = 79;

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

// Core SDL functions
int SDL_Init(uint flags);
void SDL_Quit();
void SDL_QuitSubSystem(uint flags);
const(char)* SDL_GetError();
ulong SDL_GetTicks();

// Window functions
SDL_Window* SDL_CreateWindow(const char* title, int w, int h, uint flags);
void SDL_DestroyWindow(SDL_Window* window);
void SDL_GetWindowSize(SDL_Window* window, int* w, int* h);
bool SDL_SetWindowFullscreen(SDL_Window* window, bool fullscreen);

// Renderer functions - CORRECTED based on SDL3 documentation
SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, const char* name);
void SDL_DestroyRenderer(SDL_Renderer* renderer);
int SDL_SetRenderDrawColor(SDL_Renderer* renderer, ubyte r, ubyte g, ubyte b, ubyte a);
int SDL_RenderClear(SDL_Renderer* renderer);
int SDL_RenderFillRect(SDL_Renderer* renderer, const SDL_FRect* rect);
int SDL_RenderRect(SDL_Renderer* renderer, const SDL_FRect* rect);
bool SDL_RenderPresent(SDL_Renderer* renderer); // Returns bool in SDL3
bool SDL_SetRenderVSync(SDL_Renderer* renderer, int vsync);

// Texture and surface functions
bool SDL_RenderTexture(SDL_Renderer* renderer, SDL_Texture* texture, const SDL_FRect* srcrect, const SDL_FRect* dstrect);
SDL_Texture* SDL_CreateTextureFromSurface(SDL_Renderer* renderer, SDL_Surface* surface);
void SDL_DestroyTexture(SDL_Texture* texture);
SDL_Surface* SDL_LoadBMP(const char* file);
void SDL_DestroySurface(SDL_Surface* surface);

// Event functions
bool SDL_PollEvent(SDL_Event* event);

// Input functions
const(ubyte)* SDL_GetKeyboardState(int* numkeys);

// Audio types and constants
alias SDL_AudioDeviceID = uint;
struct SDL_AudioStream;

struct SDL_AudioSpec {
	int freq;
	uint format;
	ubyte channels;
	ubyte padding;
	uint samples;
	uint silence;
	uint size;
	void function(void* userdata, ubyte* stream, int len) callback;
	void* userdata;
}

enum SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK = 0;
enum SDL_AUDIO_DEVICE_ALLOW_ANY_CHANGE = 0x00000001 | 0x00000002 | 0x00000004 | 0x00000008;

// Audio functions - Note: SDL3 audio API has significant changes
SDL_AudioDeviceID SDL_OpenAudioDevice(
	const(char)* device,
	const(SDL_AudioSpec)* desired,
	SDL_AudioSpec* obtained,
	int allowed_changes
);
void SDL_CloseAudioDevice(SDL_AudioDeviceID dev);
SDL_AudioStream* SDL_CreateAudioStream(
	uint src_format, ubyte src_channels, int src_rate,
	uint dst_format, ubyte dst_channels, int dst_rate
);
void SDL_DestroyAudioStream(SDL_AudioStream* stream);
int SDL_BindAudioStreams(SDL_AudioDeviceID dev, SDL_AudioStream** streams, int num_streams);
int SDL_QueueAudio(SDL_AudioDeviceID dev, const(void)* data, uint len);
uint SDL_GetAudioDeviceQueueSize(SDL_AudioDeviceID dev);
void SDL_PauseAudioDevice(SDL_AudioDeviceID dev);
void SDL_ResumeAudioDevice(SDL_AudioDeviceID dev);
