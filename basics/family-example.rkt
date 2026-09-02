#lang roulette/example/probalog 

% Classic family-relations Datalog, with one uncertain parentage
% record so uncertainty propagates into the derived relations.
%
% No Sibling: it needs disequality (x != y), which probalog lacks.

% --- Family tree -------------------------------------------------
% Tom + Mary -> Alice, Ed        John + Sue -> Bob
% Alice + Bob -> Carol, Dave     Ed + Fay -> Gina  (Ed only 70%)

Male("Tom").
Male("John").
Male("Bob").
Male("Dave").
Male("Ed").

Female("Mary").
Female("Sue").
Female("Alice").
Female("Carol").
Female("Fay").
Female("Gina").

Parent("Tom", "Alice").
Parent("Mary", "Alice").
Parent("Tom", "Ed").
Parent("Mary", "Ed").
Parent("John", "Bob").
Parent("Sue", "Bob").
Parent("Alice", "Carol").
Parent("Bob", "Carol").
Parent("Alice", "Dave").
Parent("Bob", "Dave").
Parent("Ed", "Gina") :: 0.7.
Parent("Fay", "Gina").

% --- Derived relations --------------------------------------------

Ancestor(x, y) :- Parent(x, y).
Ancestor(x, z) :- Ancestor(x, y), Parent(y, z).

Grandfather(x, y) :- Parent(x, z), Parent(z, y), Male(x).
Grandmother(x, y) :- Parent(x, z), Parent(z, y), Female(x).

Son(x, y) :- Parent(y, x), Male(x).
Daughter(x, y) :- Parent(y, x), Female(x).

% --- Queries --------------------------------------------------------

? Grandfather("Tom", "Carol").
? Grandmother("Mary", "Carol").
? Ancestor("Tom", "Carol").

? Ancestor("Tom", "Gina").      % 0.7, via the uncertain record

? Son("Dave", "Alice").
? Daughter("Carol", "Bob").
