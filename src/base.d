module base;

version(none) public import core.stdc.errno;
public import core.stdc.stdio;

public import std.math;
public import std.string : fromStringz, toStringz;
public import std.random : Random, uniform;
public import std.algorithm.searching : maxElement;
public import std.algorithm.iteration : map;
public import std.algorithm.comparison : min, max, clamp;

public import nxt.geometry;
public import nxt.color;
public import nxt.colors;
public import nxt.logger;
public import nxt.io;
public import nxt.io.dbg;
public import nxt.sampling : sample;

public import sdl;

alias RGBA = ColorRGBA;

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

@safe:
