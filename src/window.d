module window;

import sdl3;

@safe:

struct Window {
	@disable this(this);
	this(in ScreenSize ssz) {
	}
	ScreenSize size() @property @trusted {
		typeof(return) ssz;
		SDL_GetWindowSize(window, &ssz.width, &ssz.height);
		return ssz;
	}
	SDL_Window* window;
}
