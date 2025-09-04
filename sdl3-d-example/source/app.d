import core.stdc.stdio;

enum SCREEN_WIDTH = 800;
enum SCREEN_HEIGHT = 600;

int main(string[] args)
{
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        stderr.fprintf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "SDL3 Complete D Application",
        SCREEN_WIDTH, SCREEN_HEIGHT,
        SDL_WINDOW_RESIZABLE
    );

    if (window is null) {
        stderr.fprintf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(window, null);
    if (renderer is null) {
        stderr.fprintf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    if (!SDL_SetRenderVSync(renderer, 1)) // enable adaptive VSync if supported, otherwise regular VSync
        stderr.fprintf("Warning: VSync not supported, falling back to no VSync\n");
	else
        printf("VSync enabled\n");

    bool quit = false;
    SDL_Event e;

    float rect_x = SCREEN_WIDTH / 2.0f - 25;
    float rect_y = SCREEN_HEIGHT / 2.0f - 25;
    float vel_x = 100.0f; // pixels per second
    float vel_y = 150.0f;
    ulong last_time = SDL_GetTicks();

    printf("SDL3 D Application Started\n");
    printf("Controls:\n");
    printf("  ESC or close window to quit\n");
    printf("  SPACE to reset bouncing rectangle\n");

    while (!quit) {
        ulong current_time = SDL_GetTicks();
        float delta_time = (current_time - last_time) / 1000.0f;
        last_time = current_time;

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
                        case SDLK_SPACE:
                            // Reset rectangle position
                            rect_x = SCREEN_WIDTH / 2.0f - 25;
                            rect_y = SCREEN_HEIGHT / 2.0f - 25;
                            vel_x = 100.0f;
                            vel_y = 150.0f;
                            printf("Rectangle reset!\n");
                            break;
                        default:
                            break;
                    }
                    break;

                case SDL_EVENT_WINDOW_RESIZED:
                    printf("Window resized to %dx%d\n", e.window.data1, e.window.data2);
                    break;

                default:
                    break;
            }
        }

        rect_x += vel_x * delta_time;
        rect_y += vel_y * delta_time;

        if (rect_x <= 0 || rect_x >= SCREEN_WIDTH - 50) {
            vel_x = -vel_x;
            rect_x = (rect_x <= 0) ? 0 : SCREEN_WIDTH - 50;
        }
        if (rect_y <= 0 || rect_y >= SCREEN_HEIGHT - 50) {
            vel_y = -vel_y;
            rect_y = (rect_y <= 0) ? 0 : SCREEN_HEIGHT - 50;
        }

        SDL_SetRenderDrawColor(renderer, 25, 25, 112, 255);
        SDL_RenderClear(renderer);

        SDL_FRect rect = SDL_FRect(rect_x, rect_y, 50, 50);
        SDL_SetRenderDrawColor(renderer, 255, 165, 0, 255);
        SDL_RenderFillRect(renderer, &rect);

        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        SDL_FRect border = SDL_FRect(10, 10, SCREEN_WIDTH - 20, SCREEN_HEIGHT - 20);
        SDL_RenderRect(renderer, &border);

        SDL_RenderPresent(renderer); // present and wait for VSync
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

extern(C) nothrow @nogc:

struct SDL_Window;
struct SDL_Renderer;

enum uint SDL_INIT_VIDEO = 0x00000020;
enum uint SDL_WINDOW_RESIZABLE = 0x00000020;

enum uint SDL_EVENT_QUIT = 0x100;
enum uint SDL_EVENT_KEY_DOWN = 0x300;
enum uint SDL_EVENT_WINDOW_RESIZED = 0x203;

enum uint SDLK_ESCAPE = 27;
enum uint SDLK_SPACE = 32;

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
    ubyte[128] padding; // Ensure enough space for any event
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
void SDL_Delay(uint ms);
ulong SDL_GetTicks();
const(char)* SDL_GetError();
