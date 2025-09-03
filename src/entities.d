module entities;

import raylib;
alias Vec2 = Vector2;

@safe:

// TODO: Move to `nxt.geometry`
struct Circle {
	Vec2 centerPosition;
	float radius;
}

// TODO: Move to `nxt.geometry`
struct Square {
	Vec2 centerPosition;
	float radius;
}

// TODO: Move to `nxt.geometry`
struct Box {
	Vec2 centerPosition;
	Vec2 size;
}
