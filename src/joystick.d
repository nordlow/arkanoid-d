module joystick;

import base;

import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.stdio;
import core.stdc.errno;

@safe:

Joystick openDefaultJoystick() nothrow
	=> typeof(return)("/dev/input/js0");

struct JoystickEvent {
	alias ButtonOrAxis = ubyte;
	alias AxisValue = short;
	enum Type {
		none, // for the sake of (implicit) cast to `bool`
		buttonPressed,
		buttonReleased,
		axisMoved
	}
	Type type;
	ButtonOrAxis buttonOrAxis;
	AxisValue axisValue; // for `Type.axisMoved` events
	uint timestamp; // event timestamp in milliseconds
@property const pure nothrow @nogc:
	bool opCast(T: bool)() => type != Type.none;
}

struct Joystick {
nothrow:
	@disable this(this);

	enum ButtonState : ubyte {
		released = 0,
		pressed = 0,
	}

	enum AxisState : ubyte {
		neutral = 0,	// Axis is in neutral/center position
		negative = 1,  // Axis is held in negative direction (left/up)
		positive = 2	// Axis is held in positive direction (right/down)
	}

	this(in char[] devicePath) @trusted {
		import std.string : toStringz;
		this._fd = open(devicePath.toStringz, O_RDONLY | O_NONBLOCK);
		if (_fd == -1) {
			perror(("Could not open joystick " ~ devicePath).ptr);
			return; // leave _fd as -1 to indicate failure
		}

		// Set the file descriptor to non-blocking mode.
		// This is optional if O_NONBLOCK is used in open(), but
		// ensures the flag is set if the file was opened differently.
		const flags = fcntl(_fd, F_GETFL, 0);
		if (flags == -1) {
			perror("Could not get file descriptor flags");
			close(_fd);
			_fd = -1;
			return;
		}
		fcntl(_fd, F_SETFL, flags | O_NONBLOCK);
	}

	~this() @trusted {
		if (_fd >= 0)
			close(_fd);
	}

	@property bool isValid() const pure nothrow @nogc => _fd >= 0;

	/++ Returns: `true` iff `buttonNumber` is currently being pressed (held), `false` otherwise +/
	ButtonState stateOf(in JoystickEvent.ButtonOrAxis buttonNumber) const pure nothrow @nogc
		=> _buttonStates[buttonNumber];

	/++ Returns: An array of buttons that are currently pressed|held. +/
	JoystickEvent.ButtonOrAxis[] getHeldButtons() const pure nothrow {
		typeof(return) ret;
		ret.reserve(32); // reasonable initial capacity
		foreach (const JoystickEvent.ButtonOrAxis i, const state; _buttonStates)
			if (state == ButtonState.pressed)
				ret ~= i;
		return ret;
	}

	/++ Try to read the next joystick event.
	 + Returns: `JoystickEvent` that evaluates to false if no event is available,
	 +			otherwise returns the event details.
	 + Note: Automatically updates the internal button hold state tracking.
	 +/
	JoystickEvent tryNextEvent() @trusted in(isValid) {
		import core.sys.posix.poll : pollfd, poll, POLLIN;
		alias R = typeof(return);

		js_event rawEvent;
		auto pfd = pollfd(_fd, POLLIN);

		// Check if there's data available with 0ms timeout
		if (poll(&pfd, 1, 0) <= 0 || !(pfd.revents & POLLIN))
			return R(R.Type.none);

		const bytesRead = read(_fd, &rawEvent, js_event.sizeof);
		if (bytesRead != js_event.sizeof) {
			if (bytesRead == -1)
				perror("Error reading from joystick");
			return R(R.Type.none);
		}

		if (rawEvent.type & JS_EVENT_INIT) {
			if (rawEvent.type & JS_EVENT_BUTTON)
				setButtonState(rawEvent);
			return R(R.Type.none);
		}

		R event;
		event.buttonOrAxis = rawEvent.number;
		event.timestamp = rawEvent.time;

		if (rawEvent.type & JS_EVENT_BUTTON) {
			event.type = (rawEvent.value == 1) ? R.Type.buttonPressed : R.Type.buttonReleased;
			setButtonState(rawEvent);
		} else if (rawEvent.type & JS_EVENT_AXIS) {
			event.type = R.Type.axisMoved;
			event.axisValue = rawEvent.value;
		} else
			event.type = R.Type.none;

		return event;
	}
private:
	void setButtonState(in js_event rawEvent) scope pure nothrow @nogc {
		const pressed = rawEvent.value == 1;
		_buttonStates[rawEvent.number] = pressed ? ButtonState.pressed : ButtonState.released;
	}
	int _fd; // device file descriptor
	ButtonState[256] _buttonStates; // button states indexed by button number
}

extern (C) {
	struct js_event {
		uint time;	   // event timestamp in milliseconds
		short value;	 // (axis) value
		ubyte type;	   // event type
		ubyte number;	// axis/button number
	}

	enum {
		JS_EVENT_BUTTON = 0x01,
		JS_EVENT_AXIS = 0x02,
		JS_EVENT_INIT = 0x80
	}
}
