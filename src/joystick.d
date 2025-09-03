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

enum JoystickEventType {
    none,
    buttonPressed,
    buttonReleased,
    axisMoved
}

struct JoystickEvent {
    JoystickEventType type;
    ubyte number;        // button/axis number
    short value;         // axis value (for axisMoved events)
    uint timestamp;      // event timestamp in milliseconds

	bool opCast(T : bool)() const pure nothrow @safe @nogc { return type != JoystickEventType.none; }

    @property bool isButton() const pure nothrow @nogc {
        return type == JoystickEventType.buttonPressed ||
               type == JoystickEventType.buttonReleased;
    }

    @property bool isAxis() const pure nothrow @nogc {
        return type == JoystickEventType.axisMoved;
    }

    @property bool isPressed() const pure nothrow @nogc {
        return type == JoystickEventType.buttonPressed;
    }
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
            return JoystickEvent(JoystickEventType.none);
        }

        const bytesRead = read(fd, &rawEvent, js_event.sizeof);
        if (bytesRead != js_event.sizeof) {
            if (bytesRead == -1) {
                perror("Error reading from joystick");
            }
            return JoystickEvent(JoystickEventType.none);
        }

        // Skip initialization events
        if (rawEvent.type & JS_EVENT_INIT) {
            return JoystickEvent(JoystickEventType.none);
        }

        JoystickEvent event;
        event.number = rawEvent.number;
        event.timestamp = rawEvent.time;

        if (rawEvent.type & JS_EVENT_BUTTON) {
            event.type = (rawEvent.value == 1) ?
                        JoystickEventType.buttonPressed :
                        JoystickEventType.buttonReleased;
        } else if (rawEvent.type & JS_EVENT_AXIS) {
            event.type = JoystickEventType.axisMoved;
            event.value = rawEvent.value;
        } else {
            event.type = JoystickEventType.none;
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
        while ((event = tryNextEvent()).type != JoystickEventType.none) {
            final switch (event.type) {
                case JoystickEventType.buttonPressed:
                    warning("Button ", event.number, " pressed");
                    break;
                case JoystickEventType.buttonReleased:
                    warning("Button ", event.number, " released");
                    break;
                case JoystickEventType.axisMoved:
                    warning("Axis ", event.number, " moved to ", event.value);
                    break;
                case JoystickEventType.none:
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
