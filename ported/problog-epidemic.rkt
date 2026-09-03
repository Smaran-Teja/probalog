#lang roulette/example/probalog

% Spread of an infection through a contact network over time, after
% ProbLog's epidemic/viral-marketing examples.
%
% Probalog has no arithmetic, so time is unrolled: the days are
% constants and `Next` links them. That is the general recipe for
% temporal models here -- write out the time steps and give each one
% its own random variables, since each day's transmission is an
% independent event.
%
% What makes *this* temporal model expressible is that it is monotone:
% once infected, always infected. A hidden Markov model over mutually
% exclusive states (rainy today *or* sunny today, not both) cannot be
% written, because saying "sunny means not rainy" needs either negation
% or an annotated disjunction, and probalog has neither.
%
% The contact network:
%
%     ann --- bob --- cal
%      \             /
%       \           /
%        `--- dee -'

Next(0, 1).
Next(1, 2).
Next(2, 3).

Contact("ann", "bob").
Contact("bob", "cal").
Contact("ann", "dee").
Contact("dee", "cal").

% Contact is symmetric; one fact per pair, both directions off it.
Meets(x, y) :- Contact(x, y).
Meets(x, y) :- Contact(y, x).

% Patient zero.
Infected(0, "ann").

% --- Transmission ------------------------------------------------------
% One coin flip per (day, contact pair): whether the infection crossed
% that link on that day. Separate facts per day, because meeting again
% tomorrow is a fresh chance to catch it.

Transmits(0, "ann", "bob") :: 0.3.
Transmits(1, "ann", "bob") :: 0.3.
Transmits(2, "ann", "bob") :: 0.3.
Transmits(0, "bob", "ann") :: 0.3.
Transmits(1, "bob", "ann") :: 0.3.
Transmits(2, "bob", "ann") :: 0.3.

Transmits(0, "bob", "cal") :: 0.3.
Transmits(1, "bob", "cal") :: 0.3.
Transmits(2, "bob", "cal") :: 0.3.
Transmits(0, "cal", "bob") :: 0.3.
Transmits(1, "cal", "bob") :: 0.3.
Transmits(2, "cal", "bob") :: 0.3.

% ann and dee are housemates: a higher rate on that link.
Transmits(0, "ann", "dee") :: 0.6.
Transmits(1, "ann", "dee") :: 0.6.
Transmits(2, "ann", "dee") :: 0.6.
Transmits(0, "dee", "ann") :: 0.6.
Transmits(1, "dee", "ann") :: 0.6.
Transmits(2, "dee", "ann") :: 0.6.

Transmits(0, "dee", "cal") :: 0.3.
Transmits(1, "dee", "cal") :: 0.3.
Transmits(2, "dee", "cal") :: 0.3.
Transmits(0, "cal", "dee") :: 0.3.
Transmits(1, "cal", "dee") :: 0.3.
Transmits(2, "cal", "dee") :: 0.3.

% --- The model ---------------------------------------------------------

% Infection persists: this is the clause that makes the model monotone,
% and so expressible without negation.
Infected(t1, x) :- Infected(t0, x), Next(t0, t1).

% ...and spreads along a contact that transmitted that day.
Infected(t1, y) :- Infected(t0, x), Meets(x, y), Transmits(t0, x, y), Next(t0, t1).

% Someone infected at any point in the window.
EverInfected(x) :- Infected(t, x).

% --- How it spreads ----------------------------------------------------

? Infected(0, "ann").       % #t, patient zero
? Infected(1, "ann").       % #t, persistence

% dee is the housemate, so she goes first and fastest.
? Infected(1, "dee").       % 0.6
? Infected(2, "dee").       % 1 - 0.4*0.4 = 0.84
% Slightly above the 1 - 0.4^3 = 0.936 that the ann link alone gives,
% because by day 3 dee can also have caught it back around via cal.
? Infected(3, "dee").       % 0.937728

? Infected(1, "bob").       % 0.3
? Infected(2, "bob").       % 0.51

% cal is two hops from ann either way, so he cannot be infected on
% day 1 at all, and needs a chain of two transmissions after that.
? Infected(1, "cal").       % #f
? Infected(2, "cal").       % 0.2538
? Infected(3, "cal").       % 0.512352

% Equal to Infected(3, "cal"): with persistence, "infected at some
% point" and "infected on the last day" are the same set.
? EverInfected("cal").      % 0.512352

% --- Contact tracing ---------------------------------------------------
%
% cal tests positive on day 2. Working backwards, that means the
% infection reached bob or dee on day 1 and crossed to cal on day 2.

! Infected(2, "cal").

? Infected(1, "bob").       % 0.5035, up from 0.3
? Infected(1, "dee").       % 0.8582, up from 0.6
? Infected(3, "dee").       % 0.9841

% --- Ruling a route out -------------------------------------------------
%
% bob's day-1 test comes back negative, so cal must have caught it
% from dee.

! ~Infected(1, "bob").

? Infected(1, "dee").       % #t: the only remaining route to cal
? Transmits(0, "ann", "dee").   % #t
? Transmits(1, "dee", "cal").   % #t
% bob was clear on day 1, so day 2 is a fresh single chance from ann.
? Infected(2, "bob").       % 0.3
