# Arkanoid Clone in D.

Just type `dub` to run.

## TODO
- Use SDL function that does combined create window and renderer.
- Add tesselation of shapes and store all `SDL_Vertex[vertexCount]`
  plus associated colors in `Renderer` and draw these using
  `SDL_RenderGeometry`.
- Add `float angle` and `float angleVelocity` entity properties.
- Add `Vec2 rot` and `Vec2 rotVelocity` entity properties.
- Use `SDL_gamepad` API
- Adjust moves of balls so they don't go outside the border.
- Record sound effects sounds and play upon events such as bounce
- Add rotation property to entities. Check how SDL represents rotation.
- Use static introspection to
  - update `Game` `Scene` graph
  - draw `Game` `Scene` graph
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
