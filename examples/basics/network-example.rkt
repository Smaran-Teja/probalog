#lang probalog

Edge("a", "b") :: 0.5.
Edge("b", "c") :: 0.5.

Path(x, y) :- Edge(x, y).
Path(x, z) :- Path(x, y), Edge(y, z).

? Path("a", "b").
? Path("a", "c").
? Path("b", "c").
