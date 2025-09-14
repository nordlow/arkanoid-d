/++ SDL Audio.
	See_Also: https://talesm.github.io/SDL3pp/group__CategoryAudio.html
	See_Also: https://talesm.github.io/SDL3pp/SDL3pp__audio_8h_source.html
 +/
module sdl.audio;

import sdl;

@safe:

struct AudioSpec {
nothrow:
	SDL_AudioSpec _spec;
	alias this = _spec; // for now
}

struct WAV {
	import nxt.path : FilePath;
	@disable this(this);
	this(in FilePath path) @trusted {
		if (!SDL_LoadWAV(path.str.toStringz, &_spec._spec, &audio_buf, &audio_len))
			errorf("Failed to load WAV: %s", SDL_GetError().fromStringz);
	}
	~this() @trusted {
		 if (audio_buf)
			 SDL_free(audio_buf);
	}
@property:
	AudioSpec spec() const scope pure nothrow => _spec;
private:
	AudioSpec _spec;
	Uint8* audio_buf;
	Uint32 audio_len;
}

struct AudioStream {
/+ nothrow: +/
	@disable this(this);
	this(in AudioSpec spec) @trusted {
		// TODO: this cast shouldn' be needed. Add extern(C) to override.
		_ptr = SDL_CreateAudioStream(cast(SDL_AudioSpec*)(&spec._spec), null);
		infof("Successfully created audio stream at %s", _ptr);
	}
	~this() @trusted {
		infof("Destroying audio stream at %s", _ptr);
		SDL_DestroyAudioStream(_ptr);
	}
	private SDL_AudioStream* _ptr;
	invariant(_ptr);
}

struct AudioDevice {
	/+ nothrow: +/
	@disable this(this);
	this(in AudioSpec desiredSpec,
	  uint devid = SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK) @trusted {
		int allowed_changes;
		// TODO: this cast shouldn' be needed. Add extern(C) to override.
		_id = SDL_OpenAudioDevice(devid, cast(SDL_AudioSpec*)(&desiredSpec._spec));
		if (_id == 0) {
			criticalf("Failed to open audio: %s", SDL_GetError().fromStringz);
			return;
		}
		infof("Successfully opened audio device id %s", _id);
	}
	~this() {
		if (_id != 0)
			close();
	}
	void bind(ref AudioStream stream) @trusted {
		if (!SDL_BindAudioStream(_id, stream._ptr))
			errorf("Failed to bind to device: %s", SDL_GetError().fromStringz);
	}
	/// Close `this`.
	void close() @trusted => SDL_CloseAudioDevice(_id);
	/// Start audio playback.
	void start() @trusted @il { SDL_ResumeAudioDevice(_id); }
	/// Stop audio playback.
	void stop() @trusted @il { SDL_PauseAudioDevice(_id); }
	SDL_AudioDeviceID _id;
	invariant(_id);
}
