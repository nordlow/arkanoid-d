module joystick;
import nxt.io;
import nxt.logger;
import core.sys.posix.poll;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.stdio;
import core.stdc.errno;

@safe:

Joystick openDefaultJoystick() nothrow => typeof(return)("/dev/input/js0");

struct JoystickEvent {
	enum Type {
		none,
		buttonPressed,
		buttonReleased,
		axisMoved
	}
    Type type;
    ubyte number;        // button/axis number
    short value;         // axis value (for `Type.axisMoved` events)
    uint timestamp;      // event timestamp in milliseconds

@property const pure nothrow @nogc:
	bool opCast(T: bool)() => type != Type.none;
    bool isButton() => (type == Type.buttonPressed || type == Type.buttonReleased);
    bool isAxis() => type == Type.axisMoved;
    bool isPressed() => type == Type.buttonPressed;
}

struct Joystick {
    int fd;

nothrow:
    @disable this(this);

    this(in char[] devicePath) @trusted {
        import std.string : toStringz;
        this.fd = open(devicePath.toStringz, O_RDONLY | O_NONBLOCK);
        if (fd == -1) {
            perror(("Could not open joystick " ~ devicePath).ptr);
            return; // Leave fd as -1 to indicate failure
        }

        // Set the file descriptor to non-blocking mode.
        // This is optional if O_NONBLOCK is used in open(), but
        // ensures the flag is set if the file was opened differently.
        const flags = fcntl(fd, F_GETFL, 0);
        if (flags == -1) {
            perror("Could not get file descriptor flags");
            close(fd);
            fd = -1;
            return;
        }
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }

    ~this() @trusted {
        if (fd >= 0) {
            close(fd);
        }
    }

    @property bool isValid() const pure nothrow @nogc {
        return fd >= 0;
    }

    /++
     + Try to read the next joystick event.
     + Returns: JoystickEvent with type 'none' if no event is available,
     +          otherwise returns the event details.
     +/
    JoystickEvent tryNextEvent() @trusted
    in(isValid, "Joystick must be valid before reading events") {
        js_event rawEvent;
        auto pfd = pollfd(fd, POLLIN);

        // Check if there's data available with 0ms timeout
        if (poll(&pfd, 1, 0) <= 0 || !(pfd.revents & POLLIN)) {
            return JoystickEvent(JoystickEvent.Type.none);
        }

        const bytesRead = read(fd, &rawEvent, js_event.sizeof);
        if (bytesRead != js_event.sizeof) {
            if (bytesRead == -1) {
                perror("Error reading from joystick");
            }
            return JoystickEvent(JoystickEvent.Type.none);
        }

        // Skip initialization events
        if (rawEvent.type & JS_EVENT_INIT) {
            return JoystickEvent(JoystickEvent.Type.none);
        }

        JoystickEvent event;
        event.number = rawEvent.number;
        event.timestamp = rawEvent.time;

        if (rawEvent.type & JS_EVENT_BUTTON) {
            event.type = (rawEvent.value == 1) ?
                        JoystickEvent.Type.buttonPressed :
                        JoystickEvent.Type.buttonReleased;
        } else if (rawEvent.type & JS_EVENT_AXIS) {
            event.type = JoystickEvent.Type.axisMoved;
            event.value = rawEvent.value;
        } else {
            event.type = JoystickEvent.Type.none;
        }

        return event;
    }

    /++
     + Read and process all pending joystick events.
     + This is a convenience method that reads all available events
     + and logs them using the warning function.
     +/
    void processPendingEvents() @trusted
    in(isValid, "Joystick must be valid before processing events") {
        JoystickEvent event;
        while ((event = tryNextEvent()).type != JoystickEvent.Type.none) {
            final switch (event.type) {
                case JoystickEvent.Type.buttonPressed:
                    warning("Button ", event.number, " pressed");
                    break;
                case JoystickEvent.Type.buttonReleased:
                    warning("Button ", event.number, " released");
                    break;
                case JoystickEvent.Type.axisMoved:
                    warning("Axis ", event.number, " moved to ", event.value);
                    break;
                case JoystickEvent.Type.none:
                    break; // This case is handled by the while condition
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
