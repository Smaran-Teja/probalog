#lang probalog

Edge("a", "b").
Edge("b", "c").
Path(x, y) :- Edge(x, y).
Path(x, z) :- Path(x, y), Edge(y, z).

? Path("a", "b").
? Path("b", "c").
? Path("a", "c").
