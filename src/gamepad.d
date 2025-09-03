module gamepad;

@safe:

void raylib_detectGamepad() @trusted {
	import raylib : IsGamepadAvailable, GetGamepadName, IsGamepadButtonDown;
	import nxt.logger : info;
	foreach (const gamepad; -1000 .. 1000) {
		if (IsGamepadAvailable(gamepad))
			continue;
		import std.string : fromStringz;
		info("Gamepad: nr ", gamepad, " being ", GetGamepadName(gamepad).fromStringz, " detected");
		foreach (const button; -100 .. 100) {
			if (!IsGamepadButtonDown(gamepad, button))
				continue;
			info("Button ", button, " is down");
		}
	}
}
