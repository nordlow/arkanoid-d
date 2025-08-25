module waveform;

@safe:

import std.math : sin, pow, PI;
import std.random : Random, uniform;

import raylib : Wave;

alias SoundSample = short;
alias SS = SoundSample;

// DSL Components
// ---

// The main struct that defines a sound's properties.
// It uses delegates for a flexible, declarative approach.
struct Waveform {
    float dur;

    // A delegate for the frequency envelope: returns frequency in Hz at time t [0..1]
    float delegate(in float t) freq;
    // A delegate for the amplitude envelope: returns amplitude from 0.0 to 1.0 at time t [0..1]
    float delegate(in float t) amplitude;
    // The core generator: returns a sample from -1.0 to 1.0
    float delegate(in float t, float f) generator;

    // Generates the final Wave struct from the declarative description.
    Wave generate(in int sampleRate) const {
        const frameCount = cast(int)(sampleRate * dur);
        SS[] data = new SS[frameCount];

        foreach (const i; 0 .. frameCount) {
            const float t = cast(float)i / frameCount;
            const float currentFreq = freq(t);
            const float currentAmp = amplitude(t);
            const float sample = generator(t, currentFreq) * 16000 * currentAmp;
            data[i] = cast(SS)(sample);
        }

        // Return a new Wave struct with the generated data
        return Wave(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * SS.sizeof, channels: 1, data: &data[0]);
    }

    // Overload for when a Random generator is needed
    Wave generate(in int sampleRate, scope ref Random rng) {
        const frameCount = cast(int)(sampleRate * dur);
        SS[] data = new SS[frameCount];

        foreach (const i; 0 .. frameCount) {
            const float t = cast(float)i / frameCount;
            const float currentFreq = freq(t);
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

Wave generateStaticWave(in float freq, in float dur, in int sampleRate) {
	WaveformGenerators wg;
    return Waveform(
        dur: dur,
		freq: (in float t) => freq,
		amplitude: (in float t) => 1.0f,
        generator: (in float t, float f) => wg.sine(t * dur * sampleRate, f)
    ).generate(sampleRate);
}

Wave generateBounceWave(in float startFreq, in float endFreq, in float dur, in int sampleRate) {
	WaveformGenerators wg;
    return Waveform(
        dur: dur,
        // Exponential frequency sweep
        freq: (in float t) => startFreq * pow(endFreq / startFreq, t),
        // Fast decay amplitude
        amplitude: (in float t) => pow(1.0f - t, 2.0f),
        generator: (in float t, float f) => wg.sine(t * dur * sampleRate, f)
    ).generate(sampleRate);
}

Wave generateBoingWave(in float startFreq, in float endFreq, in float dur, in int sampleRate) {
	WaveformGenerators wg;
    return Waveform(
        dur: dur,
        // custom frequency curve
        freq: (in float t) => startFreq * (1.0f - pow(t, 2.0f)) + endFreq * pow(t, 2.0f),
        // very fast percussive decay
        amplitude: (in float t) => pow(1.0f - t, 4.0f),
        generator: (in float t, float f) => wg.sine(t * dur * sampleRate, f)
    ).generate(sampleRate);
}

Wave generateGlassBreakWave(in float dur, in int sampleRate) {
	WaveformGenerators wg;

    auto shatter = Waveform(
        dur: dur,
        freq: (in float t) => t.init, // not used by noise
        amplitude: (in float t) => pow(1.0f - t, 8.0f), // very fast decay
        generator: (in float t, float f) => wg.noise(t, f)
    );

    auto tinkle = Waveform(
        dur: dur,
        freq: (in float t) => 10000.0f,
        amplitude: (in float t) => 0.5f * (1.0f - t), // slower linear decay
        generator: (in float t, float f) => wg.sine(t, f)
    );

    // Generate both waves
    Wave shatterWave = shatter.generate(sampleRate);
    Wave tinkleWave = tinkle.generate(sampleRate);

	// TODO: Use a `WaveformCombinator`

	return shatterWave;
}
