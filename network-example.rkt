#lang probalog

Edge("a", "b") :: 0.8.
Edge("b", "c") :: 0.8.
Path(x, y) :- Edge(x, y).
Path(x, z) :- Path(x, y), Edge(y, z).

? Path("a", "b").
? Path("b", "c").
? Path("a", "c").
