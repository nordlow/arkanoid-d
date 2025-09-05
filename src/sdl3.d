module sdl3;

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

struct SDL_Color { ubyte r, g, b, a; }

struct SDL_FRect { float x, y, w, h; }

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

int SDL_Init(uint flags);
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

void SDL_QuitSubSystem(uint flags);
const(char)* SDL_GetError();
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
