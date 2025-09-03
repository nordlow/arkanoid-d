module joystick;

import nxt.io;
import nxt.logger;

import core.sys.posix.poll;
import core.sys.posix.sys.types;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.stdio;
import core.sys.posix.signal;
import core.stdc.errno;

@safe:

Joystick openDefaultJoystick() nothrow => typeof(return)("/dev/input/js0");

struct Joystick {
	int fd;
nothrow:
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
void readPendingEvents(ref Joystick js) @trusted in(js.fd >= 0) {
    js_event event;

    // Create a pollfd structure for the joystick file descriptor
    pollfd pfd;
    pfd.fd = js.fd;
    pfd.events = POLLIN; // Wait for incoming data

    // Check if there are any events to read with a 0ms timeout
    while (poll(&pfd, 1, 0) > 0) {

        if (pfd.revents & POLLIN) {
            // Data is available, so read it
            const bytesRead = read(js.fd, &event, js_event.sizeof);

            if (bytesRead > 0) {
                // Event was read successfully
                if (event.type & JS_EVENT_BUTTON) {
                    if (event.value == 1) {
                        writeln("Button ", event.number, " pressed");
                    } else {
                        writeln("Button ", event.number, " released");
                    }
                } else if (event.type & JS_EVENT_AXIS) {
                    writeln("Axis ", event.number, " moved to ", event.value);
                }
            } else if (bytesRead == -1) {
                // An actual error occurred during read
                perror("Error reading from joystick");
                break;
            }
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
