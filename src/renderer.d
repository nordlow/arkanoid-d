module renderer;

import sdl3;

@safe:

// TODO: Use this instead.
struct Renderer {
	@disable this(this);
	SDL_Renderer* _renderer;
}
