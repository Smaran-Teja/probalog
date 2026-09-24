#lang probalog

% Taint analysis, from PSouffle's language_taint_mini regression case
% (FMCAD 2026, https://doi.org/10.5281/zenodo.20091940).
%
% Does untrusted data reach a sink? The original uses two features
% probalog lacks -- negation (`!sanitizer(Dst)`) and rule weights
% (`0.80::alarm(V) :- ...`). Both are encoded away exactly, not
% approximated; see `Passes` and `Fires`.

% --- Sources -----------------------------------------------------------

Source("user") :: 0.55.
Source("config") :: 0.21.

% --- The flow graph ----------------------------------------------------
%
% Each edge holds independently. Two routes reach "network", which is
% what makes it a disjunction rather than a product.

Flow("user", "parser") :: 0.88.
Flow("parser", "network") :: 0.77.
Flow("user", "cache") :: 0.66.
Flow("cache", "network") :: 0.74.
Flow("config", "log") :: 0.59.
Flow("log", "network") :: 0.64.

% --- Sanitizers, without negation --------------------------------------
%
% The original body is `..., flow(Src, Dst), !sanitizer(Dst)`. probalog
% is positive Datalog, but `sanitizer` is certain and given up front, so
% its complement is a fixed set: `Passes` is "not a sanitizer", computed
% by hand. Exact only because `sanitizer` is closed and certain -- a
% probabilistic or derived one would need real stratified negation.
%
% Sanitized: "parser". Everything else passes.

Passes("user").
Passes("config").
Passes("cache").
Passes("log").
Passes("network").

% --- Taint propagation -------------------------------------------------

Tainted(value) :- Source(value).
Tainted(dst) :- Tainted(src), Flow(src, dst), Passes(dst).

% --- Sinks -------------------------------------------------------------

Sink("network").
Sink("cache").

% --- The alarm, without rule weights -----------------------------------
%
% `0.80::alarm(V) :- tainted(V), sink(V).` A weighted rule fires
% independently per grounding, so the weight moves into a fresh fact in
% the body -- one `Fires` per sink is exactly the set of groundings.

Fires("network") :: 0.8.
Fires("cache") :: 0.8.

Alarm(value) :- Tainted(value), Sink(value), Fires(value).

% --- Taint answers -----------------------------------------------------

? Tainted("user").      % 0.55, straight from the source
? Tainted("config").    % 0.21

% Reached only through the sanitizer, so nothing derives it.
? Tainted("parser").    % #f

? Tainted("cache").     % 0.55 * 0.66 = 0.363
? Tainted("log").       % 0.21 * 0.59 = 0.1239

% Two independent routes; the parser route is cut by the sanitizer.
%   a = 0.55 * 0.66 * 0.74 = 0.26862   (user->cache->network)
%   b = 0.21 * 0.59 * 0.64 = 0.079296  (config->log->network)
? Tainted("network").   % 1 - (1-0.26862)(1-0.079296) = 0.32661550848

% --- Alarms ------------------------------------------------------------
% Both match PSouffle's own output exactly.

? Alarm("cache").       % 0.8 * 0.363 = 0.2904
? Alarm("network").     % 0.8 * 0.32661550848 = 0.261292406784

% Tainted, but not a sink.
? Alarm("log").         % #f

% --- Conditioning on an alarm ------------------------------------------
%
% The cache alarm's derivation is a single chain, so every link settles.

! Alarm("cache").

? Source("user").               % #t
? Flow("user", "cache").        % #t
? Fires("cache").               % #t

% "network" shares the user->cache edge, so one route is confirmed up to
% its last edge: 1 - (1 - 0.74)(1 - 0.079296) = 0.76061696
? Tainted("network").           % 0.76061696
? Alarm("network").             % 0.8 * that = 0.608493568
