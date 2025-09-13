module aliases;

@safe:

import nxt.geometry;

/++ Position. +/
alias Pos = Point!(float, 2);

/++ Vector. +/
alias Vec = Vector!(float, 2, false);

/++ Direction. +/
alias Dir = Vector!(float, 2, true);

/++ Dimension(s). +/
alias Dim = Vector!(float, 2);

/++ Velocity. +/
alias Vel = Vector!(float, 2, false);

/++ Rectangle. +/
alias Rect = Rectangle!(float);

/++ Triangle. +/
struct Triangle {
	Pos[3] vertices;
}
alias Tri = Triangle;

/++ Circle. +/
alias Cir = Circle!(float);

/++ Quadangle. +/
struct Quadangle {
	Pos[4] vertices;
}
alias Quad = Quadangle;
