#lang roulette/example/probalog

% Mendelian inheritance of a recessive disease, after ProbLog's
% genetics/bloodtype examples.
%
% This is the port that fits probalog best, because the one
% probabilistic primitive it needs -- a parent passes one of their two
% alleles, each with probability 1/2 -- is exactly a fact with `:: 0.5`
% on it. ProbLog's bloodtype example needs annotated disjunctions to
% pick among three alleles; a two-allele recessive trait needs only a
% coin flip per meiosis, which is expressible as-is.
%
% The pedigree:
%
%     gpa + gma        mom
%          \           /
%           \         /
%            dad + mom
%             /      \
%           ann      ben
%
% "Carrier" means carrying at least one copy of the mutant allele.
% "Affected" means having two, one from each parent -- which is what
% makes the disease recessive.

% --- Founders ----------------------------------------------------------
% Population carrier frequency for the three people who marry in.

Carrier("gpa") :: 0.1.
Carrier("gma") :: 0.1.
Carrier("mom") :: 0.1.

% --- The pedigree ------------------------------------------------------

ParentOf("gpa", "dad").
ParentOf("gma", "dad").
ParentOf("dad", "ann").
ParentOf("mom", "ann").
ParentOf("dad", "ben").
ParentOf("mom", "ben").

% --- Meiosis -----------------------------------------------------------
% One coin flip per parent-child pair: whether that parent passed on
% the mutant copy rather than the healthy one. Each conception is its
% own independent draw, which is why ann and ben get separate facts.

Transmits("gpa", "dad") :: 0.5.
Transmits("gma", "dad") :: 0.5.
Transmits("dad", "ann") :: 0.5.
Transmits("mom", "ann") :: 0.5.
Transmits("dad", "ben") :: 0.5.
Transmits("mom", "ben") :: 0.5.

% --- Inheritance -------------------------------------------------------

% A child got a mutant copy from a parent if that parent had one to
% give and passed it along.
GotFrom(c, p) :- ParentOf(p, c), Carrier(p), Transmits(p, c).

% One copy from anywhere makes you a carrier.
Carrier(c) :- GotFrom(c, p).

% Two copies -- one from each parent -- make you affected. The parents
% have to be named explicitly: the natural rule
%
%     Affected(c) :- GotFrom(c, p1), GotFrom(c, p2).
%
% would also match p1 = p2, making every carrier affected, and
% probalog has no disequality to rule that out.
Affected("dad") :- GotFrom("dad", "gpa"), GotFrom("dad", "gma").
Affected("ann") :- GotFrom("ann", "dad"), GotFrom("ann", "mom").
Affected("ben") :- GotFrom("ben", "dad"), GotFrom("ben", "mom").

% --- Priors ------------------------------------------------------------

% dad is a carrier if either of his parents was and passed it on:
% 1 - (1 - 0.1*0.5)^2
? Carrier("dad").           % 0.0975

? Carrier("ann").           % 1 - (1 - 0.0975*0.5)(1 - 0.1*0.5)

% Affected needs both parents to transmit, so the risk is tiny.
? Affected("ann").          % 0.0975*0.5 * 0.1*0.5 = 0.0024375
? Affected("ben").          % the same
? Affected("dad").          % 0.1*0.5 * 0.1*0.5 = 0.0025

% --- A diagnosis -------------------------------------------------------
%
% ann is born affected. That is only possible if both parents carry and
% both transmitted, so it settles a great deal at once.

! Affected("ann").

? Carrier("dad").           % #t
? Carrier("mom").           % #t

% Now the classic pedigree result: with both parents known carriers,
% each later child has a 1-in-4 risk -- 1/2 from each parent,
% independently drawn.
? Affected("ben").          % 0.25
? Carrier("ben").           % 1 - 0.5*0.5 = 0.75

% Evidence also flows *up* the pedigree. dad must have got his copy
% from gpa or gma, so both of their carrier probabilities rise sharply
% from the 0.1 population rate.
? Carrier("gpa").           % 0.538, up from 0.1
? Carrier("gma").           % 0.538

% --- A second child, unaffected ----------------------------------------
%
% ben turns out healthy. That rules out the both-transmitted case for
% him and drops his carrier probability from 0.75 to 2/3.

! ~Affected("ben").

? Affected("ben").          % #f
? Carrier("ben").           % 0.5/0.75 = 0.6667
? Affected("ann").          % #t, unchanged -- ann's diagnosis stands
