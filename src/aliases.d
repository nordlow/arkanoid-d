module aliases;

@safe:

import nxt.geometry;

/++ Position. +/
alias Pos2 = Point!(float, 2);

/++ Vector. +/
alias Vec2 = Vector!(float, 2, false);

/++ Direction. +/
alias Dir2 = Vector!(float, 2, true);

/++ Dimension(s). +/
alias Dim2 = Vector!(float, 2);

/++ Velocity. +/
alias Vel2 = Vector!(float, 2, false);

/++ Rectangle. +/
alias Rect = Rectangle!(float);

/++ Triangle. +/
struct Triangle {
	Pos2[3] vertices;
}
alias Tri = Triangle;

/++ Quadangle. +/
struct Quadangle {
	Pos2[4] vertices;
}
alias Quad = Quadangle;
