module aliases;

@safe:

import nxt.geometry;

alias Pos2 = Point!(float, 2);

alias Vec2 = Vector!(float, 2, false);
alias Dim2 = Vector!(float, 2);
alias Vel2 = Vector!(float, 2, false);
alias Dir2 = Vector!(float, 2, true);

alias Rect = Rectangle!(float);
