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
    bool isReleased() => type == Type.buttonReleased;
}

struct Joystick {
    int fd;
    private bool[256] buttonStates; // Track button states, indexed by button number

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
     + Check if a specific button is currently held down.
     + Params: buttonNumber = The button number to check
     + Returns: true if the button is currently pressed, false otherwise
     +/
    bool isButtonHeld(ubyte buttonNumber) const pure nothrow @nogc {
        return buttonStates[buttonNumber];
    }

    /++
     + Get all currently held button numbers.
     + Returns: An array of button numbers that are currently pressed
     +/
    ubyte[] getHeldButtons() const pure nothrow {
        ubyte[] held;
        held.reserve(32); // Reasonable initial capacity
        foreach (ubyte i, bool pressed; buttonStates)
            if (pressed)
                held ~= i;
        return held;
    }

    /++
     + Get the number of buttons currently being held.
     + Returns: Count of pressed buttons
     +/
    size_t getHeldButtonCount() const pure nothrow @nogc {
        size_t count = 0;
        foreach (bool pressed; buttonStates)
            if (pressed) count++;
        return count;
    }

    /++
     + Try to read the next joystick event.
     + Returns: JoystickEvent that evaluates to false if no event is available,
     +          otherwise returns the event details.
     + Note: This method automatically updates the internal button state tracking.
     +/
    JoystickEvent tryNextEvent() @trusted
    in(isValid, "Joystick must be valid before reading events") {
        js_event rawEvent;
        auto pfd = pollfd(fd, POLLIN);

        // Check if there's data available with 0ms timeout
        if (poll(&pfd, 1, 0) <= 0 || !(pfd.revents & POLLIN))
            return JoystickEvent(JoystickEvent.Type.none);

        const bytesRead = read(fd, &rawEvent, js_event.sizeof);
        if (bytesRead != js_event.sizeof) {
            if (bytesRead == -1)
                perror("Error reading from joystick");
            return JoystickEvent(JoystickEvent.Type.none);
        }

        // Skip initialization events but still update button states from them
        if (rawEvent.type & JS_EVENT_INIT) {
            if (rawEvent.type & JS_EVENT_BUTTON)
                buttonStates[rawEvent.number] = (rawEvent.value == 1);
            return JoystickEvent(JoystickEvent.Type.none);
        }

        JoystickEvent event;
        event.number = rawEvent.number;
        event.timestamp = rawEvent.time;

        if (rawEvent.type & JS_EVENT_BUTTON) {
            event.type = (rawEvent.value == 1) ?
                        JoystickEvent.Type.buttonPressed :
                        JoystickEvent.Type.buttonReleased;

            // Update button state tracking
            buttonStates[rawEvent.number] = (rawEvent.value == 1);
        } else if (rawEvent.type & JS_EVENT_AXIS) {
            event.type = JoystickEvent.Type.axisMoved;
            event.value = rawEvent.value;
        } else
            event.type = JoystickEvent.Type.none;

        return event;
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
