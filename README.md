# Arkanoid Clone in D.

See also https://github.com/vhspace/sdl3-rs specifically
https://github.com/vhspace/sdl3-rs/tree/master/examples.

Just type `dub` to run.

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

### Engine
- Add `bake()` to all `Ent`-types in `entities.d`.
- Represent rotations using `Ang rotation`.
- Add `float rotation` and `float rotationVelocity` entity properties.
- Add `Vec2 rot` and `Vec2 rotVelocity` entity properties.

### Game
+ Sten brickor som inte går sönder
+ Längre paddel och flera paddlar
+ Göra paddeln rundad som i riktiga Arkanoid
+ Två brickor
+ Brickor spricker i bitar


<!-- Local Variables: -->
<!-- gptel-model: grok-beta -->
<!-- gptel--backend-name: "xAI" -->
<!-- gptel--bounds: nil -->
<!-- End: -->
