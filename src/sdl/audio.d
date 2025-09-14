/++ SDL Audio.
	See_Also: https://talesm.github.io/SDL3pp/group__CategoryAudio.html
	See_Also: https://talesm.github.io/SDL3pp/SDL3pp__audio_8h_source.html
 +/
module sdl.audio;

import sdl;

@safe:

struct AudioSpec {
nothrow:
	@disable this(this);
	SDL_AudioSpec _spec;
	alias this = _spec; // for now
}

struct AudioStream {
nothrow:
	@disable this(this);
	SDL_AudioStream* _ptr;
	invariant(_ptr);
}

struct AudioDevice {
	/+ nothrow: +/
	@disable this(this);
	void open(const(char)* device = cast(const(char)*)SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK) @trusted {
		SDL_AudioSpec desired;
		SDL_AudioSpec obtained;
		int allowed_changes;
		SDL_AudioDeviceID dev = SDL_OpenAudioDevice(device: device, null, null, allowed_changes);
		if (dev == 0)
			return criticalf("Failed to open audio: %s", SDL_GetError());
		infof("Successfully opened audio device id %s", dev);
	}
	~this() {
		if (_id != 0)
			close();
	}
	/// Close `this`.
	void close() @trusted => SDL_CloseAudioDevice(_id);
	/// Start audio playback.
	void start() @trusted @il { SDL_ResumeAudioDevice(_id); }
	/// Stop audio playback.
	void stop() @trusted @il { SDL_PauseAudioDevice(_id); }

	SDL_AudioDeviceID _id;
}
