module waveform;

@safe:

import std.stdio;
import std.math;
import std.random;
import std.typecons : Nullable;

import raylib : Wave;

alias SoundSample = short;

// DSL Components
// ---

// The main struct that defines a sound's properties.
// It uses delegates for a flexible, declarative approach.
struct Waveform {
    float dur;

    // A delegate for the frequency envelope: returns frequency in Hz at time t [0..1]
    float delegate(in float t) frequency;
    // A delegate for the amplitude envelope: returns amplitude from 0.0 to 1.0 at time t [0..1]
    float delegate(in float t) amplitude;
    // The core generator: returns a sample from -1.0 to 1.0
    float delegate(in float t, float freq) generator;

    // Generates the final Wave struct from the declarative description.
    Wave generate(in int sampleRate) const {
        alias SS = SoundSample;
        const frameCount = cast(int)(sampleRate * dur);
        SS[] data = new SS[frameCount];

        foreach (const i; 0 .. frameCount) {
            const float t = cast(float)i / frameCount;
            const float currentFreq = frequency(t);
            const float currentAmp = amplitude(t);
            const float sample = generator(t, currentFreq) * 16000 * currentAmp;
            data[i] = cast(SS)(sample);
        }

        // Return a new Wave struct with the generated data
        return Wave(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * SS.sizeof, channels: 1, data: &data[0]);
    }

    // Overload for when a Random generator is needed
    Wave generate(in int sampleRate, scope ref Random rng) {
        alias SS = SoundSample;
        const frameCount = cast(int)(sampleRate * dur);
        SS[] data = new SS[frameCount];

        foreach (const i; 0 .. frameCount) {
            const float t = cast(float)i / frameCount;
            const float currentFreq = frequency(t);
            const float currentAmp = amplitude(t);
            const float sample = generator(t, currentFreq) * 16000 * currentAmp;
            data[i] = cast(SS)(sample);
        }

        // Return a new Wave struct with the generated data
        return Wave(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * SS.sizeof, channels: 1, data: &data[0]);
    }
}

struct WaveformGenerators {
	Random rng;
    float sine(in float t, in float f) => sin(2.0f * PI * f * t);
    float noise(in float t, in float _f) => uniform(-1.0f, 1.0f, rng);
}

// DSL-Based Sound Generation Functions
// ---

// Generates a static tone using the DSL
Wave generateStaticWave(in float frequency, in float dur, in int sampleRate) {
	WaveformGenerators wg;
    return Waveform(
        dur: dur,
        // Constant frequency
        frequency: (in float t) => frequency,
        // Constant amplitude
        amplitude: (in float t) => 1.0f,
        // Using the sine generator
        generator: (in float t, float freq) => wg.sine(t * dur * sampleRate, freq)
    ).generate(sampleRate);
}

// Generates a bouncing tone using the DSL
Wave generateBounceWave(in float startFreq, in float endFreq, in float dur, in int sampleRate) {
	WaveformGenerators wg;
    return Waveform(
        dur: dur,
        // Exponential frequency sweep
        frequency: (in float t) => startFreq * pow(endFreq / startFreq, t),
        // Fast decay amplitude
        amplitude: (in float t) => pow(1.0f - t, 2.0f),
        // Using the sine generator
        generator: (in float t, float freq) => wg.sine(t * dur * sampleRate, freq)
    ).generate(sampleRate);
}

// Generates a boing tone using the DSL
Wave generateBoingWave(in float startFreq, in float endFreq, in float dur, in int sampleRate) {
	WaveformGenerators wg;
    return Waveform(
        dur: dur,
        // Custom frequency curve
        frequency: (in float t) => startFreq * (1.0f - pow(t, 2.0f)) + endFreq * pow(t, 2.0f),
        // Very fast percussive decay
        amplitude: (in float t) => pow(1.0f - t, 4.0f),
        // Using the sine generator
        generator: (in float t, float freq) => wg.sine(t * dur * sampleRate, freq)
    ).generate(sampleRate);
}

// Generates a glass break sound by mixing two DSL waveforms
Wave generateGlassBreakWave(in float dur, in int sampleRate) {
	WaveformGenerators wg;

    // Waveform for the "shatter" noise
    auto shatter = Waveform(
        dur: dur,
        frequency: (in float t) => 0.0f, // Frequency is not relevant for noise
        amplitude: (in float t) => pow(1.0f - t, 8.0f), // Very fast decay
        generator: (in float t, float freq) => wg.noise(t, freq)
    );

    // Waveform for the high-frequency "tinkle" tone
    auto tinkle = Waveform(
        dur: dur,
        frequency: (in float t) => 10000.0f,
        amplitude: (in float t) => 0.5f * (1.0f - t), // Slower linear decay
        generator: (in float t, float freq) => wg.sine(t, freq)
    );

    // Generate both waves
    Wave shatterWave = shatter.generate(sampleRate);
    Wave tinkleWave = tinkle.generate(sampleRate);

	// TODO: Use a `WaveformCombinator`

	return shatterWave;
}
