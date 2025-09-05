module aliases;

@safe:

import nxt.geometry;

alias Pos2 = Point!(float, 2);
alias Dim2 = Point!(float, 2); // TODO: Add Dimension/Size whatever to `nxt.geometry`
alias Vec2 = Vector!(float, 2, false);
alias NVec2 = Vector!(float, 2, true);
alias Rect = Rectangle!(float);
