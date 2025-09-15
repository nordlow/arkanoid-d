/++ SDL Audio.
	See_Also: https://talesm.github.io/SDL3pp/group__CategoryAudio.html
	See_Also: https://talesm.github.io/SDL3pp/SDL3pp__audio_8h_source.html
 +/
module sdl.audio;

import nxt.path : FilePath;
import sdl;

@safe:

struct AudioSpec {
nothrow:
	SDL_AudioSpec _spec;
	alias this = _spec; // for now
}

struct AudioDevice {
	/+ nothrow: +/
	@disable this(this);
	this(in AudioSpec desiredSpec, uint devid = SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK) @trusted {
		int allowed_changes;
		// TODO: this cast shouldn' be needed. Add extern(C) to override.
		_id = SDL_OpenAudioDevice(devid, cast(SDL_AudioSpec*)(&desiredSpec._spec));
		if (_id == 0) {
			criticalf("Failed to open audio: %s", SDL_GetError().fromStringz);
			return;
		}
		tracef("Successfully opened audio device id %s", _id);
	}
	~this() {
		if (_id != 0)
			close();
	}
	/++ Bind `stream`. +/
	void bind(ref AudioStream stream) @trusted {
		if (!SDL_BindAudioStream(_id, stream._ptr))
			errorf("Failed to bind %s to device %s: %s", stream._ptr, _id,
				   SDL_GetError().fromStringz);
	}
	void close() @trusted {
		tracef("Closing audio device %s", _id);
		SDL_CloseAudioDevice(_id);
	}
	/// Resume all audio playback associated with `this` device.
	void resume() @trusted @il { SDL_ResumeAudioDevice(_id); }
	/// Pause all audio playback associated with `this` device.
	void pause() @trusted @il { SDL_PauseAudioDevice(_id); }
	SDL_AudioDeviceID _id;
	invariant(_id);
}

struct AudioStream {
/+ nothrow: +/
	@disable this(this);
	this(in AudioSpec spec) @trusted {
		// TODO: this cast shouldn' be needed. Add extern(C) to override.
		_ptr = SDL_CreateAudioStream(cast(SDL_AudioSpec*)(&spec._spec), null);
		tracef("Successfully created audio stream at %s", _ptr);
	}
	~this() @trusted {
		tracef("Destroying %s ...", _ptr);
		SDL_DestroyAudioStream(_ptr);
	}
	/++ Unbind `this`. +/
	void unbind() @trusted {
		tracef("Unbinding %s ...", _ptr);
		return SDL_UnbindAudioStream(_ptr);
	}
	void put(in AudioBuffer buf) scope @trusted {
		if (!SDL_PutAudioStreamData(_ptr, buf._ptr, cast(int)buf._length)) {
			errorf("Failed to queue audio data: %s", SDL_GetError().fromStringz);
			return;
		}
	}
	void clearAndPut(in AudioBuffer buf) scope @trusted {
		clear();
		return put(buf);
	}
	/++ Tell the stream that you're done sending data, and anything being
		buffered should be converted/resampled and made available
		immediately. +/
	void flush() scope @trusted {
		if (!SDL_FlushAudioStream(_ptr))
			return errorf("Failed to flush %s: %s", _ptr, SDL_GetError().fromStringz);
	}
	/++ Clear|Drop any queued|pending data in the stream. +/
	void clear() scope @trusted {
		if (!SDL_ClearAudioStream(_ptr))
			return errorf("Failed to clear %s: %s", _ptr, SDL_GetError().fromStringz);
	}
	/++ Lock `this` for serialized access. +/
	void lock() scope @trusted {
		if (!SDL_LockAudioStream(_ptr))
			return errorf("Failed to lock %s: %s", _ptr, SDL_GetError().fromStringz);
	}
	/++ Unlock `this` for serialized access. +/
	void unlock() scope @trusted {
		if (!SDL_LockAudioStream(_ptr))
			return errorf("Failed to unlock %s: %s", _ptr, SDL_GetError().fromStringz);
	}
	// TODO:
	// SDL_GetAudioStreamData(): Retrieves converted audio data from the stream.
	/+ SDL_DrainAudioStream(): Waits for all queued data to be consumed before returning. +/
	/+ SDL_GetAudioStreamAvailable(): Returns the amount of converted audio data, in bytes, currently available to be retrieved from the stream. +/
	/+ SDL_GetAudioStreamQueued(): Returns the amount of raw, unconverted audio data, in bytes, currently queued in the stream. +/
	private SDL_AudioStream* _ptr;
}

struct AudioBuffer {
	@disable this(this);
	~this() @trusted {
		 if (_ptr)
			 SDL_free(_ptr);
	}
@property:
	AudioSpec spec() const scope pure nothrow => _spec;
private:
	AudioSpec _spec;
	void* _ptr;
	uint _length;
}

AudioBuffer loadWAV(in FilePath path) @trusted {
	typeof(return) ret;
	if (!SDL_LoadWAV(path.str.toStringz, &ret._spec._spec, cast(ubyte**)&ret._ptr, &ret._length))
		errorf("Failed to load WAV from %s: %s", path, SDL_GetError().fromStringz);
	return ret;
}
alias readWAV = loadWAV;

/++ Audio (Sound) Effect. +/
struct AudioFx {
	@disable this(this);
	AudioStream stream;
	AudioBuffer buffer;
	void reput() {
		stream.clearAndPut(buffer);
	}
}
