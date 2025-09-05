module audiostream;

import std.exception : enforce;
import nxt.logger;

version(none)
struct AudioStream {
    SDL_AudioDeviceID deviceID;
    SDL_AudioStream* stream;
    // You could also store a pointer to the queued data if needed
    // void* dataBuffer;
    // size_t dataSize;

    /// Initializes and opens the audio device and stream.
    this(const SDL_AudioSpec* spec) {
        enforce(SDL_Init(SDL_INIT_AUDIO) == 0, "Failed to initialize SDL_AUDIO");

        deviceID = SDL_OpenAudioDevice(
            SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
            spec,
            null,
            SDL_AUDIO_DEVICE_ALLOW_ANY_CHANGE
        );
        enforce(deviceID != 0, "Failed to open audio device");

        // The stream format matches the device spec for simplicity
        stream = SDL_CreateAudioStream(
            spec.format, spec.channels, spec.freq,
            spec.format, spec.channels, spec.freq
        );
        enforce(stream, "Failed to create audio stream");

        SDL_BindAudioStreams(deviceID, &stream, 1);
        info("Audio stream initialized successfully.");
    }

    /// Queues audio data for playback.
    void queue(const void* data, size_t size) {
        enforce(SDL_QueueAudio(deviceID, data, cast(Uint32)size) == 0, "Failed to queue audio data");
    }

    /// Starts audio playback.
    void play() {
        SDL_ResumeAudioDevice(deviceID);
    }

    /// Stops audio playback.
    void stop() {
        SDL_PauseAudioDevice(deviceID);
    }

    /// Returns the number of bytes left in the queue.
    size_t getQueueSize() const {
        return SDL_GetAudioDeviceQueueSize(deviceID);
    }

    /// Cleans up resources.
    ~this() {
        if (stream) {
            SDL_UnbindAudioStreams(deviceID, &stream, 1);
            SDL_DestroyAudioStream(stream);
        }
        if (deviceID != 0) {
            SDL_CloseAudioDevice(deviceID);
        }
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
		info("Audio stream cleaned up.");
    }
}

import sdl3;
