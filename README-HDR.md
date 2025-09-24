Per Nordlöw <per.nordlow@gmail.com>

lör 20 sep. 09:06 (för 4 dagar sedan)

till mig
#include <stdio.h>
#include <SDL3/SDL.h>

int main(int argc, char* argv[]) {
	if (SDL_Init(SDL_INIT_VIDEO) != 0) {
		fprintf(stderr, "SDL_Init Error: %s\n", SDL_GetError());
		return 1;
	}

	SDL_Window* window = SDL_CreateWindow("HDR Check", 800, 600, SDL_WINDOW_RESIZABLE);
	if (window == NULL) {
		fprintf(stderr, "SDL_CreateWindow Error: %s\n", SDL_GetError());
		SDL_Quit();
		return 1;
	}

	SDL_Renderer* renderer = SDL_CreateRenderer(window, NULL);
	if (renderer == NULL) {
		fprintf(stderr, "SDL_CreateRenderer Error: %s\n", SDL_GetError());
		SDL_DestroyWindow(window);
		SDL_Quit();
		return 1;
	}

	// --- HDR Detection ---
	SDL_PropertiesID props = SDL_GetRendererProperties(renderer);
	if (props == 0) {
		fprintf(stderr, "Failed to get renderer properties: %s\n", SDL_GetError());
	} else {
		SDL_bool hdr_enabled = SDL_GetBooleanProperty(props, SDL_PROP_RENDERER_HDR_ENABLED_BOOLEAN, SDL_FALSE);
		if (hdr_enabled) {
			printf("HDR is enabled!\n");

			float sdr_white_point = SDL_GetFloatProperty(props, SDL_PROP_RENDERER_SDR_WHITE_POINT_FLOAT, 0.0f);
			float hdr_headroom = SDL_GetFloatProperty(props, SDL_PROP_RENDERER_HDR_HEADROOM_FLOAT, 0.0f);

			printf("SDR White Point: %.2f nits\n", sdr_white_point);
			printf("HDR Headroom: %.2f\n", hdr_headroom);

		} else {
			printf("HDR is NOT enabled on this renderer.\n");
		}
	}

	// The rest of your main loop and cleanup would go here...
	// For this example, we'll just clean up and exit.

	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	SDL_Quit();

	return 0;
}
