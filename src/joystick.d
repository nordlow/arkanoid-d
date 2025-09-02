module joystick;

import nxt.io;

import core.sys.posix.sys.types;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.stdio;

@safe:

struct Joystick {
	int fd;
	@disable this(this);
	this(const char* devicePath) @trusted {
		import std.string : fromStringz;
		auto fd = open(devicePath, O_RDONLY | O_NONBLOCK);
		if (fd == -1)
			perror(("Could not open joystick " ~ devicePath.fromStringz).ptr);
		// Set the file descriptor to non-blocking mode.
		// This is optional if O_NONBLOCK is used in open(), but
		// ensures the flag is set if the file was opened differently.
		const flags = fcntl(fd, F_GETFL, 0);
		if (flags == -1) {
			perror("Could not get file descriptor flags");
			close(fd);
			return;
		}
		fcntl(fd, F_SETFL, flags | O_NONBLOCK);
	}
	~this() @trusted {
		close(fd);
	}
}

/++ Read all pending {Joystick|Gamepad} events. +/
void readPendingEvents(ref Joystick js) @trusted {
    // Loop until read() returns -1, indicating no more events are available
    // for now (EAGAIN/EWOULDBLOCK).
    js_event event;
    while (read(js.fd, &event, js_event.sizeof) > 0) {
        if (event.type & JS_EVENT_BUTTON) {
            if (event.value == 1) {
                writeln("Button ", event.number, " pressed");
            } else {
                writeln("Button ", event.number, " released");
            }
        } else if (event.type & JS_EVENT_AXIS) {
            writeln("Axis ", event.number, " moved to ", event.value);
        }
    }
}

extern (C) {
    struct js_event {
        uint time;     // event timestamp in milliseconds
        short value;   // value
        ubyte type;    // event type
        ubyte number;  // axis/button number
    }
    enum {
        JS_EVENT_BUTTON = 0x01,
        JS_EVENT_AXIS = 0x02,
        JS_EVENT_INIT = 0x80
    }
}
