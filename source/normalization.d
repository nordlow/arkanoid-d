/++ Common normalizations for audio samples. +/
module normalization;

import std.math : sqrt, abs;
import std.algorithm.comparison : min, max, clamp;
import std.algorithm.searching : maxElement;
import waves : Sample;

@safe:

// Method 1: Peak Normalization (most common)
void peakNormalize(scope float[] data, in float targetLevel = 1.0f) pure nothrow @nogc {
	const peak = data.maxElement;
	if (peak == 0)
		return; // avoid division by zero
    const float scaleFactor = targetLevel / peak;
    foreach (ref sample; data)
        sample *= scaleFactor;
}

// Method 2: RMS Normalization (for perceived loudness)
void rmsNormalize(scope float[] data, float targetRMS = 0.25f) pure nothrow {
    // Calculate RMS (Root Mean Square)
    float sumSquares = 0.0f;
    foreach (sample; data)
        sumSquares += sample * sample;
    const float rms = sqrt(sumSquares / data.length);
    if (rms > 0.0f) {
        const float scaleFactor = targetRMS / rms;
        foreach (ref sample; data) {
            sample *= scaleFactor;
            sample = sample.clamp(-1.0f, 1.0f);
        }
    }
}

// Method 3: Soft Limiting (prevents harsh clipping)
Sample softLimit(float input, float threshold = 0.95f) pure nothrow {
    const float absInput = abs(input);
    if (absInput <= threshold) {
        return cast(Sample)(input * Sample.max);
    } else {
        // Soft compression above threshold
        const float excess = absInput - threshold;
        const float compressed = threshold + excess / (1.0f + excess * 2.0f);
        const float sign = input >= 0.0f ? 1.0f : -1.0f;
        return cast(Sample)(sign * compressed * Sample.max);
    }
}
