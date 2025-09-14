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

struct AudioBuffer {
	import nxt.path : FilePath;
	@disable this(this);
	this(in FilePath pathWAV) @trusted {
		// TODO: Generalize to any sound file.
		if (!SDL_LoadWAV(pathWAV.str.toStringz, &_spec._spec, cast(ubyte**)&_ptr, &_length))
			errorf("Failed to load WAV: %s", SDL_GetError().fromStringz);
	}
	~this() @trusted {
		 if (_ptr)
			 SDL_free(_ptr);
	}
@property:
	AudioSpec spec() const scope pure nothrow => _spec;
private:
	AudioSpec _spec;
	void* _ptr;
	Uint32 _length;
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
	void put(in AudioBuffer buf) scope @trusted {
		if (!SDL_PutAudioStreamData(_ptr, buf._ptr, cast(int)buf._length)) {
			errorf("Failed to queue audio data: %s", SDL_GetError().fromStringz);
			return;
		}
	}
	void reput(in AudioBuffer buf) scope @trusted {
		flush();
		return put(buf);
	}
	void flush() scope @trusted {
		if (!SDL_FlushAudioStream(_ptr))
			return errorf("Failed to flush audio stream %s: %s", _ptr, SDL_GetError().fromStringz);
	}
	// TODO:
	// SDL_GetAudioStreamData(): Retrieves converted audio data from the stream.
	/+ SDL_FlushAudioStream(): Flushes (discards) all queued data in the stream's buffer. +/
	/+ SDL_ClearAudioStream(): Clears the entire stream, including internal buffers and queued data. +/
	/+ SDL_DrainAudioStream(): Waits for all queued data to be consumed before returning. +/
	/+ SDL_GetAudioStreamAvailable(): Returns the amount of converted audio data, in bytes, currently available to be retrieved from the stream. +/
	/+ SDL_GetAudioStreamQueued(): Returns the amount of raw, unconverted audio data, in bytes, currently queued in the stream. +/
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
	/++ Bind `stream` to `this`. +/
	void bind(ref AudioStream stream) @trusted {
		if (!SDL_BindAudioStream(_id, stream._ptr))
			errorf("Failed to bind to device: %s", SDL_GetError().fromStringz);
	}
	/++ Unbind `stream` to `this`. +/
	void unbind(ref AudioStream stream) @trusted {
		infof("Unbinding audio stream %s at ...", stream._ptr);
		return SDL_UnbindAudioStream(stream._ptr);
	}
	/// Close `this`.
	void close() @trusted {
		infof("Closing audio device %s", _id);
		SDL_CloseAudioDevice(_id);
	}
	/// Start audio playback.
	void start() @trusted @il { SDL_ResumeAudioDevice(_id); }
	/// Stop audio playback.
	void stop() @trusted @il { SDL_PauseAudioDevice(_id); }
	SDL_AudioDeviceID _id;
	invariant(_id);
}
