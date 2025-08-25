module waveform;

@safe:

import std.math : sin, pow, PI;
import std.random : Random, uniform;

import raylib : Wave;

struct Static {
	float f;
	Wave generate() {
		return typeof(return)();
	}
}

struct Bounce {
	float fS; // start frequency
	float fE; // end frequency
	Wave generate() {
		return typeof(return)();
	}
}

struct Boing {
	float fS; // start frequency
	float fE; // end frequency
	Wave generate() {
		return typeof(return)();
	}
}

struct GlassBreak {
	float fS; // start frequency
	float fE; // end frequency
	Wave generate() {
		return typeof(return)();
	}
}
