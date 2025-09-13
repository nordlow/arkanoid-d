module base;

public import nxt.geometry;
public import nxt.color;
public import nxt.colors;
public import nxt.logger;

public import std.random : Random, uniform;
public import nxt.sampling : sample;

public import sdl;
public import aliases;
public import renderer;

alias RGBA = ColorRGBA;

@safe:
