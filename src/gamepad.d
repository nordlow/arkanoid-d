module gamepad;

@safe:

void raylib_detectGamepad() @trusted {
	import raylib;
	import nxt.logger : info;
	foreach (const gamepad; -1000 .. 1000) {
		if (IsGamepadAvailable(gamepad))
			continue;
		const name = GetGamepadName(gamepad);
		import std.string : fromStringz;
		info("Gamepad: nr ", gamepad, " being ", name.fromStringz, " detected");
		foreach (const button; -100 .. 100) {
			if (!IsGamepadButtonDown(gamepad, button))
				continue;
			info("Button ", button, " is down");
		}
	}
}
