/++ Common normalizations for audio samples. +/
module normalization;

import base;
import waves : Sample;

@safe:

float[] peakNormalize(scope return float[] data, in float targetLevel = 1.0f) pure nothrow @nogc {
	float peak = 0.0f;
	foreach (const ref sample; data) {
		const float absSample = abs(sample);
		if (absSample > peak) {
			peak = absSample;
		}
	}
	if (peak == 0.0f)
		return data; // avoid division by zero
	const float scaleFactor = targetLevel / peak;
	foreach (ref sample; data)
		sample *= scaleFactor;
	return data;
}

float[] peakNormalizeAlgorithmic(scope return float[] data, in float targetLevel = 1.0f) pure nothrow {
	const peak = data.map!(x => abs(x)).maxElement;
	if (peak == 0.0f)
		return data;
	const float scaleFactor = targetLevel / peak;
	foreach (ref sample; data)
		sample *= scaleFactor;
	return data;
}

/++ Method 2: RMS Normalization (for perceived loudness) +/
float[] rmsNormalize(scope return float[] data, in float targetRMS = 0.25f) pure nothrow {
	// Calculate RMS (Root Mean Square)
	float sumSquares = 0.0f;
	foreach (const ref sample; data)
		sumSquares += sample * sample;
	const float rms = sqrt(sumSquares / data.length);
	if (rms == 0)
		return data; // avoid division by zero
	const float scaleFactor = targetRMS / rms;
	foreach (ref sample; data) {
		sample *= scaleFactor;
		sample = sample.clamp(-1.0f, 1.0f);
	}
	return data;
}

// Method 3: Soft Limiting (prevents harsh clipping)
Sample softLimit(float input, float threshold = 0.95f) pure nothrow {
	const float absInput = abs(input);
	if (absInput <= threshold) {
		return cast(Sample)(input * Sample.max);
	} else {
		// soft compression above threshold
		const float excess = absInput - threshold;
		const float compressed = threshold + excess / (1.0f + excess * 2.0f);
		const float sign = input >= 0.0f ? 1.0f : -1.0f;
		return cast(Sample)(sign * compressed * Sample.max);
	}
}
