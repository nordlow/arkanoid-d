module waves;

import std.random;
import std.math;
import waveform;
import normalization;
import raylib : Wave;

alias SampleRate = uint;
alias FrameCount = uint;
alias Sample = short;

@safe:

Wave generateStaticWave(in float frequency, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];
	foreach (const i; 0 .. frameCount)
        data[i] = cast(Sample)(sin(2.0f * cast(float)std.math.PI * frequency * i / sampleRate) * Sample.max);

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateBounceWave(in float startFreq, in float endFreq, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];
    foreach (const i; 0 .. frameCount) {
        // calculate the current frequency using an exponential sweep for a natural chirp effect
        const currentFreq = startFreq * pow(endFreq / startFreq, cast(float)i / frameCount);
        const amplitude = pow(1.0f - cast(float)i / frameCount, 2.0f); // fast amplitude envelope decay
        const sample = sin(2.0f * cast(float)std.math.PI * currentFreq * i / sampleRate) * Sample.max * amplitude;
        data[i] = cast(Sample)(sample);
    }

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateBoingWave(in float startFreq, in float endFreq, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];

    // Create a smooth frequency curve for the "boing"
    float frequencyCurve(float t) {
        // a combination of a sharp initial drop and a slower rise
        return startFreq * (1.0f - pow(t, 2.0f)) + endFreq * pow(t, 2.0f);
    }

    float amplitudeEnvelope(float t) {
        return pow(1 - t, 4.0f); // a very fast, percussive decay
    }

    foreach (const i; 0 .. frameCount) {
        const t = cast(float)i / frameCount;
        const currentFreq = frequencyCurve(t);
        const currentAmp = amplitudeEnvelope(t);
        const sample = sin(2.0f * cast(float)std.math.PI * currentFreq * i / sampleRate) * Sample.max * currentAmp;
        data[i] = cast(Sample)(sample);
    }

	debug data.showStats();
    return Wave(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateGlassBreakWave(scope ref Random rng, in float duration, in float amplitude, in SampleRate sampleRate) @safe {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];

    foreach (const i; 0 .. frameCount) {
        const t = cast(float)i / frameCount;

        // Amplitude envelope for the initial "shatter"
        const shatterAmp = pow(1.0f - t, 8.0f); // Very fast, percussive decay for the noise
		const noiseSample = uniform(-1.0f, 1.0f, rng) * Sample.max * shatterAmp;

        // Amplitude envelope for the "tinkle" effect
        const tinkleAmp = 0.5f * (1.0f - t); // Slower, linear decay for the high-frequency tone
        // Generate a high-frequency sine wave for the "tinkle"
        // This makes it sound less like static and more like breaking glass
        const tinkleSample = sin(2.0f * cast(float)std.math.PI * 10000.0f * i / sampleRate) * Sample.max * tinkleAmp;

        const combinedSample = amplitude*(noiseSample * 0.7f + tinkleSample * 0.3f);

        data[i] = cast(Sample)(combinedSample);
    }

	debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generateScreamWave(scope ref Random rng, in float duration, in SampleRate sampleRate) @safe {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];

    // Define a frequency range for the scream
    const float startFreq = 200.0f; // Lower frequency for the start
    const float endFreq = 2000.0f; // High frequency for the peak of the scream

    // Define the overall amplitude envelope
    float amplitudeEnvelope(float t) {
        // A sharp rise and a slower, noisy decay
        // This simulates the vocal cords tightening and then relaxing
        return pow(t, 0.5f) * pow(1.0f - t, 2.0f);
    }

    // Define a frequency sweep that rises quickly and then levels off
    float frequencySweep(float t) {
        return startFreq + (endFreq - startFreq) * pow(t, 1.0f/3.0f);
    }

    foreach (const i; 0 .. frameCount) {
        const t = cast(float)i / frameCount;

        // Combine a sine wave with the frequency sweep
        const sineWave = sin(2.0f * cast(float)std.math.PI * frequencySweep(t) * i / sampleRate);

        // Add random high-frequency noise to simulate vocal "grit"
        const noise = uniform(-1.0f, 1.0f, rng) * 0.5f;

        // Combine the sine wave and noise, then apply the overall amplitude envelope
        const combinedSample = (sineWave * 0.7f + noise * 0.3f) * amplitudeEnvelope(t);

        // Scale and cast to the sample type
        data[i] = cast(Sample)(combinedSample * Sample.max);
    }

    debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}

Wave generatePianoWave(in float frequency, in float _amplitude, in float duration, in SampleRate sampleRate) pure nothrow {
    const frameCount = cast(FrameCount)(sampleRate * duration);
    auto data = new Sample[frameCount];
    auto floatData = new float[frameCount]; // Work in float first

    // ADSR and harmonic parameters (same as before)
    const float attackTime = 0.005f;
    const float decayTime = 0.3f;
    const float sustainLevel = 0.2f;
    const float releaseTime = duration * 0.6f;

    immutable float[8] harmonicAmplitudes = [1.0, 0.6, 0.25, 0.15, 0.08, 0.05, 0.03, 0.02];
    const float inharmonicity = 0.0001f * (frequency / 440.0f);
    float[8] harmonicFrequencies;
    foreach (const j; 0 .. harmonicFrequencies.length) {
        const float n = j + 1;
        harmonicFrequencies[j] = frequency * n * (1.0f + inharmonicity * n * n);
    }

    const float bassBoost = frequency < 200.0f ? 2.0f : 1.0f;
    const float midBoost = (frequency >= 200.0f && frequency <= 2000.0f) ? 1.2f : 1.0f;
    const float trebleRolloff = frequency > 2000.0f ? 0.7f : 1.0f;
    const float amplitudeBoost = bassBoost * midBoost * trebleRolloff;

    // Generate samples in floating point
    foreach (const i; 0 .. frameCount) {
        const float t = cast(float)i / sampleRate;
        float amplitude = 0.0;

        // ADSR envelope (same as before)
        if (t < attackTime) {
            const float attackProgress = t / attackTime;
            amplitude = attackProgress * attackProgress;
        } else if (t < attackTime + decayTime) {
            const float decayProgress = (t - attackTime) / decayTime;
            amplitude = 1.0f - decayProgress * decayProgress * (1.0f - sustainLevel);
        } else if (t < duration - releaseTime) {
            const float sustainProgress = (t - attackTime - decayTime) / (duration - releaseTime - attackTime - decayTime);
            amplitude = sustainLevel * (1.0f - sustainProgress * 0.3f);
        } else {
            const float releaseProgress = (t - (duration - releaseTime)) / releaseTime;
            const float currentSustain = sustainLevel * (1.0f - 0.3f);
            amplitude = currentSustain * exp(-releaseProgress * 3.0f);
        }

        // Generate waveform
        float sampleValue = 0.0;
        foreach (const j; 0 .. harmonicAmplitudes.length) {
            const float phaseModulation = sin(2.0 * std.math.PI * frequency * 0.1f * t) * 0.001f;
            const float phase = 2.0 * std.math.PI * harmonicFrequencies[j] * t + phaseModulation;
            const float harmonicDecay = 1.0f - (t / duration) * (j * 0.1f);
            sampleValue += harmonicAmplitudes[j] * harmonicDecay * sin(phase);
        }

        // Add subtle noise
        const float noiseLevel = 0.002f * amplitude;
        const float noise = (cast(float)((i * 1103515245 + 12345) % 32768) / 16384.0f - 1.0f) * noiseLevel;

        // Store in float array
        floatData[i] = (sampleValue + noise) * amplitude * amplitudeBoost * _amplitude;
    }

    floatData.peakNormalize(0.95f); // Leave some headroom

    foreach (const i; 0 .. frameCount) {
        // Optional: Apply soft limiting instead of hard clipping
        data[i] = floatData[i].softLimit(0.95f);
    }

    debug data.showStats();
    return typeof(return)(frameCount: frameCount, sampleRate: sampleRate, sampleSize: 8 * Sample.sizeof, channels: 1, data: &data[0]);
}


private void showStats(in Sample[] samples, in char[] funName = __FUNCTION__) {
	import std.stdio : writeln;
	import std.algorithm : minElement, maxElement;
	writeln(funName, ": range:[", samples.minElement, " ... " , samples.maxElement, "]");
}
