#lang roulette/example/probalog 

% Classic "family relations" Datalog example (a standard teaching
% program, e.g. from the Souffle benchmark suite's `family`), adapted
% to probalog's syntax. Most facts are certain vital records (no ::
% annotation, defaulting to probability 1); one parentage fact is
% marked uncertain, representing an incomplete historical record, to
% show how uncertainty propagates through derived relations.
%
% Note: classic Sibling(x,y) :- Parent(z,x), Parent(z,y), x != y
% needs disequality, which probalog doesn't support (no negation).
% Omitting the x != y check would make everyone trivially their own
% sibling, so Sibling is left out rather than defined incorrectly.

% --- Family tree -------------------------------------------------
% Tom + Mary -> Alice, Ed
% John + Sue -> Bob
% Alice + Bob -> Carol, Dave
% Ed + Fay -> Gina  (Ed's parentage of Gina is only 70% certain --
%                    an incomplete historical record)

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

% Goes through the uncertain Parent("Ed","Gina") record, so this
% should come out to probability 0.7.
? Ancestor("Tom", "Gina").

? Son("Dave", "Alice").
? Daughter("Carol", "Bob").
