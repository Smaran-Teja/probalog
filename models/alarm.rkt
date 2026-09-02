#lang roulette/example/probalog

% Pearl's burglary/earthquake alarm network.
%
% Every predicate here is nullary -- a propositional Bayes net is the
% case where predicates carry no data. Probabilities attach to facts,
% not rules, and there's no negation, so a conditional probability
% table is written as a noisy-or: one certain rule per cause, each
% guarded by its own probabilistic fact.

% --- Causes -----------------------------------------------------------

Burglary()   :: 0.01.
Earthquake() :: 0.02.

% --- P(Alarm | causes) ------------------------------------------------
% Each fact is the chance that cause actually sets the alarm off.

AlarmGivenBurglary()   :: 0.95.
AlarmGivenEarthquake() :: 0.29.
AlarmSpontaneous()     :: 0.001.   % goes off with no cause at all

Alarm() :- Burglary(),   AlarmGivenBurglary().
Alarm() :- Earthquake(), AlarmGivenEarthquake().
Alarm() :- AlarmSpontaneous().

% --- P(neighbour calls | alarm) ---------------------------------------
% John is jumpy and sometimes calls for no reason; Mary has the radio
% on and misses the alarm more often.

JohnHears()       :: 0.90.
JohnCallsAnyway() :: 0.05.
MaryHears()       :: 0.70.
MaryCallsAnyway() :: 0.02.

JohnCalls() :- Alarm(), JohnHears().
JohnCalls() :- JohnCallsAnyway().
MaryCalls() :- Alarm(), MaryHears().
MaryCalls() :- MaryCallsAnyway().

% --- Priors -----------------------------------------------------------

? Burglary().
? Earthquake().
? Alarm().
? JohnCalls().
? MaryCalls().

% --- John calls -------------------------------------------------------

! JohnCalls().

? Burglary().       % 0.135: up from 0.01, but John is weak evidence
? Earthquake().
? Alarm().

% --- Mary calls too ---------------------------------------------------

! MaryCalls().

? Alarm().          % two independent reports: near certain
? Burglary().       % 0.535
? Earthquake().

% --- ...and there was an earthquake -----------------------------------

! Earthquake().

% Explaining away: the earthquake accounts for the alarm on its own,
% so burglary drops back toward its prior.
? Burglary().       % 0.032

% --- A negative observation -------------------------------------------
% Mary never heard the alarm, so her call was one of her spurious
% ones. Satisfiable via MaryCallsAnyway(), and it retracts her call as
% corroboration.

! ~MaryHears().

? Burglary().
? Alarm().
