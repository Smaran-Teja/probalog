#lang roulette/example/probalog

% "Same generation" -- the standard Datalog benchmark, in Souffle's
% test suite and in every textbook treatment of magic sets:
%
%     sg(X,Y) :- flat(X,Y).
%     sg(X,Y) :- up(X,Z1), sg(Z1,Z2), down(Z2,Y).
%
% It is the awkward shape for bottom-up evaluation: the recursive atom
% sits in the *middle* of the body, so bindings arrive from `up` on the
% left and have to be pushed back out through `down` on the right. Each
% round joins the whole sg relation against both.
%
% Ported here onto a taxonomy where some placements are uncertain, so
% "are these two at the same rank?" gets an answer with a confidence
% rather than a yes or no.
%
%             p           q            <- two established families
%           /   \       /   \
%          a     b     c     d
%         / \         /
%        e   f       g

% --- The hierarchy -----------------------------------------------------
%
% One fact per edge. `Down` is derived from `Up` rather than declared
% separately, so an uncertain placement is a single coin flip that both
% directions share -- declaring them independently would let a link
% exist going up but not coming down.

Up("a", "p").
Up("b", "p").
Up("d", "q").
Up("e", "a").
Up("f", "a").

% Two contested placements: c under q, and g under c.
Up("c", "q") :: 0.7.
Up("g", "c") :: 0.8.

Down(parent, child) :- Up(child, parent).

% --- The base case -----------------------------------------------------
% The two root families are established as contemporaries, and each is
% trivially contemporary with itself -- which is what makes siblings
% come out as same-generation further down.

Flat("p", "q").
Flat("q", "p").
Flat("p", "p").
Flat("q", "q").

% --- The rules ---------------------------------------------------------

SameGen(x, y) :- Flat(x, y).
SameGen(x, y) :- Up(x, z1), SameGen(z1, z2), Down(z2, y).

% --- Certain answers ----------------------------------------------------

? SameGen("a", "d").        % #t: both one level down, via sg(p,q)
? SameGen("a", "b").        % #t: siblings, via sg(p,p)
? SameGen("e", "f").        % #t: siblings two levels down

% --- Answers that depend on a contested placement -----------------------

% Reaching c means going down the q -> c link.
? SameGen("a", "c").        % 0.7
? SameGen("c", "a").        % 0.7, the other direction
? SameGen("b", "c").        % 0.7

% e and g are same-generation only if both contested links hold: the
% derivation goes up e->a, across sg(a,c), then down c->g.
? SameGen("e", "g").        % 0.7 * 0.8 = 0.56

% g's rank depends on c's, so this needs the q -> c link too.
? SameGen("g", "e").        % 0.56

% Nothing places g relative to the b branch's children, since b has none.
? SameGen("g", "b").        % #f

% --- Resolving a placement ----------------------------------------------
%
% A dated source confirms e and g are contemporaries. That is only
% possible if both contested links hold, so both are settled at once.

! SameGen("e", "g").

? Up("c", "q").             % #t
? Up("g", "c").             % #t
? SameGen("a", "c").        % #t, now that c is placed
