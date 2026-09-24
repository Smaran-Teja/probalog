#lang roulette/example/probalog

% Side-channel analysis, from PSouffle's language_side_channel_mini
% regression case (FMCAD 2026, https://doi.org/10.5281/zenodo.20091940).
%
% Which observable events are explained by a possible hidden value? An
% observation is "explained" when the secret that would cause it holds
% and the monitor sees it. Ports across unchanged -- positive Datalog
% over probabilistic facts is exactly probalog's fragment.

% --- The secret --------------------------------------------------------
%
% Independent hypotheses, not a distribution: these need not sum to 1.

Secret("admin") :: 0.72.
Secret("guest") :: 0.18.

% --- What each secret would leak ---------------------------------------
% Deterministic: the program's behaviour, not a guess about it.

Mapping("admin", "cache-hit").
Mapping("guest", "cache-miss").

% --- What the attacker can see -----------------------------------------
% The monitor is imperfect, and differently so per observation.

Monitor("cache-hit") :: 0.91.
Monitor("cache-miss") :: 0.85.

% --- The analysis ------------------------------------------------------

Leak(observation) :- Secret(value), Mapping(value, observation).
Explained(observation) :- Leak(observation), Monitor(observation).

% --- Answers -----------------------------------------------------------
% One derivation each, so the probabilities just multiply along it.

? Leak("cache-hit").         % 0.72
? Leak("cache-miss").        % 0.18

? Explained("cache-hit").    % 0.72 * 0.91 = 0.6552
? Explained("cache-miss").   % 0.18 * 0.85 = 0.153

% Nothing maps to this, so no world derives it.
? Explained("timing").       % #f

% --- Conditioning on an observation ------------------------------------
%
% Seeing a cache hit settles both links: the secret was admin, and the
% monitor worked.

! Explained("cache-hit").

? Secret("admin").           % #t
? Monitor("cache-hit").      % #t

% The other branch is untouched -- it shares no facts with this one.
? Explained("cache-miss").   % 0.153
