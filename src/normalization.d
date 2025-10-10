/++ Common normalizations for (audio) samples. +/
module normalization;

import base;
import waves : Sample;

@safe:

T[] peakNormalize(T)(scope return T[] data, in T targetLevel = 1) pure nothrow @nogc {
	T peak = 0;
	foreach (const ref sample; data) {
		const T absSample = abs(sample);
		if (absSample > peak)
			peak = absSample;
	}
	if (peak == 0)
		return data; // avoid division by zero
	const T scaleFactor = targetLevel / peak;
	foreach (ref sample; data)
		sample *= scaleFactor;
	return data;
}

T[] peakNormalizeAlgorithmic(T)(scope return T[] data, in T targetLevel = 1) pure nothrow {
	const peak = data.map!(x => abs(x)).maxElement;
	if (peak == 0)
		return data;
	const T scaleFactor = targetLevel / peak;
	foreach (ref sample; data)
		sample *= scaleFactor;
	return data;
}

/++ Method 2: RMS Normalization (for perceived loudness) +/
T[] rmsNormalize(T)(scope return T[] data, in T targetRMS = 0.25) pure nothrow {
	// Calculate RMS (Root Mean Square)
	T sumSquares = 0;
	foreach (const ref sample; data)
		sumSquares += sample * sample;
	const T rms = sqrt(sumSquares / data.length);
	if (rms == 0)
		return data; // avoid division by zero
	const T scaleFactor = targetRMS / rms;
	foreach (ref sample; data) {
		sample *= scaleFactor;
		sample = sample.clamp(-1, 1);
	}
	return data;
}

// Method 3: Soft Limiting (prevents harsh clipping)
Sample softLimit(T)(T input, T threshold = 0.95) pure nothrow {
	const T absInput = abs(input);
	if (absInput <= threshold) {
		return cast(Sample)(input * Sample.max);
	} else {
		// soft compression above threshold
		const T excess = absInput - threshold;
		const T compressed = threshold + excess / (1 + excess * 2);
		const T sign = input >= 0 ? 1 : -1;
		return cast(Sample)(sign * compressed * Sample.max);
	}
}
