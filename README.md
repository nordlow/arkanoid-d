# Arkanoid Clone in D.

See also https://github.com/vhspace/sdl3-rs specifically
https://github.com/vhspace/sdl3-rs/tree/master/examples.

Just type `dub` to run.

## Set log-level via CLI flag:

The most common GNU-style command-line flags for adjusting log level are:

1. **`-v, --verbose`** - Increase verbosity (most common)
   - Often can be repeated: `-v`, `-vv`, `-vvv` for increasing levels

2. **`--debug`** - Enable debug output

3. **`-q, --quiet` or `--silent`** - Decrease verbosity/suppress output

4. **`--log-level=LEVEL`** - Explicitly set log level
   - Common values: `error`, `warning`, `info`, `debug`, `trace`

The **`-v/--verbose`** flag is by far the most standard and widely recognized across GNU tools (like `tar`, `gcc`, `curl`, etc.). It's the de facto standard for "make the output more detailed."

For applications that need more granular control, `--log-level` is also very common, especially in modern tools.

If you're designing a CLI, I'd recommend:
- `-v/--verbose` for simple verbosity increase
- `--log-level=LEVEL` if you need precise control over multiple levels

### Propagate to log-level for libsdl

For SDL3, you can set the log level using:

**1. Environment Variable (before running your application):**
```bash
export SDL_LOG=verbose
```

**2. In Code (C/C++):**
```c
#include <SDL3/SDL.h>

// Set global log priority
SDL_SetLogPriority(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_VERBOSE);

// Or set for all categories
SDL_SetLogPriorities(SDL_LOG_PRIORITY_DEBUG);
```

**Available Log Levels:**
- `SDL_LOG_PRIORITY_VERBOSE` (or `verbose` for env var)
- `SDL_LOG_PRIORITY_DEBUG` (or `debug`)
- `SDL_LOG_PRIORITY_INFO` (or `info`)
- `SDL_LOG_PRIORITY_WARN` (or `warn`)
- `SDL_LOG_PRIORITY_ERROR` (or `error`)
- `SDL_LOG_PRIORITY_CRITICAL` (or `critical`)

**Log Categories** (you can set different levels per category):
- `SDL_LOG_CATEGORY_APPLICATION`
- `SDL_LOG_CATEGORY_ERROR`
- `SDL_LOG_CATEGORY_SYSTEM`
- `SDL_LOG_CATEGORY_AUDIO`
- `SDL_LOG_CATEGORY_VIDEO`
- `SDL_LOG_CATEGORY_RENDER`
- `SDL_LOG_CATEGORY_INPUT`
- And more...

The environment variable approach is useful for debugging without recompiling.

## Provisioning of Dependencies

```sh
./provision_via_cmake.sh
```

or

```sh
./provision_via_apt.sh
```

This is also done automatically by `dub`.

## Core kinds of calculations in `update(float dt)`

1. **Motion & Transformation**
   - Move characters, projectiles, and objects based on their velocity
	 and acceleration.
   - Apply physics integration (`position += velocity * dt`, `velocity += acceleration * dt`).
   - Update rotation, scale, or any transforms tied to movement.

2. **Physics & Collision Detection**
   - Step physics simulations (rigid bodies, soft bodies, particles).
   - Detect collisions and resolve overlaps.
   - Apply gravity, drag, friction, impulses.

3. **Animations**
   - Advance skeletal animations, blend animations, update timelines.
   - Update procedural animation (like oscillations or IK).
   - Frame interpolation or tweening (`progress += speed * dt`).

4. **Game Logic & AI**
   - Run character behavior trees, finite state machines,
	 decision-making.
   - Update NPC pathfinding (e.g. move along navmesh paths).
   - Trigger scripted events or cutscenes.

5. **Timers & Cooldowns**
   - Countdown weapon cooldowns, ability timers, or status effects.
   - Manage timeouts for spawning, despawning, and delayed actions.

6. **Input Handling (frame-relative parts)**
   - Process input state changes that affect immediate movement/logic.
   - Note: polling raw input is often done separately, but applying it
	 to movement is usually here.

7. **Camera & View Logic**
   - Move/rotate the camera according to player input or scripted
	 motion.
   - Smoothly interpolate (lerp) to follow a target using `dt`.

8. **Networking (sometimes)**
   - Update interpolation/extrapolation of remote players/entities.
   - Apply prediction corrections.

9. **Audio Updates**
   - Advance positional audio based on updated transforms.
   - Update music transitions or dynamic effects tied to game state.

## TODO

### Set attributes of SDL functions
- Use `#pragma attribute(push, nothrow, nogc)`.
- C functions iterated via `traits(members, sdl.SDL)` and `pure` for a
subset of them typically property setters and getters.

See https://dlang.org/spec/importc.html#pragma-attribute

### Game
+ Sten brickor som inte går sönder
+ Längre paddel och flera paddlar
+ Göra paddeln rundad som i riktiga Arkanoid
+ Två brickor
+ Brickor spricker i bitar


### Engine
- Add `bake()` to all `Ent`-types in `entities.d`.
- Represent rotations using `Ang rotation`.
- Add `float rotation` and `float rotationVelocity` entity properties.
- Add `Vec2 rot` and `Vec2 rotVelocity` entity properties.

<!-- Local Variables: -->
<!-- gptel-model: grok-beta -->
<!-- gptel--backend-name: "xAI" -->
<!-- gptel--bounds: nil -->
<!-- End: -->
