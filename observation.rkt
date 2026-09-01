#lang roulette/example/probalog

% Network intrusion detection scenario.
%
% An attacker starts at an entry point and can pivot through the network
% by exploiting vulnerabilities. Each vulnerability has some probability
% of being present. Security sensors at various points detect traffic,
% but are unreliable -- they have a false-negative rate (miss real
% intrusions) and a false-positive rate (fire spuriously).
%
% We observe which sensors fired and which stayed silent, then ask:
% which hosts were likely compromised?

% -----------------------------------------------------------------------
% Network topology (certain -- we know the network layout)
% -----------------------------------------------------------------------

CanReach("entry",   "dmz")    .
CanReach("dmz",     "web1")   .
CanReach("dmz",     "web2")   .
CanReach("web1",    "db")     .
CanReach("web2",    "db")     .
CanReach("db",      "backup") .
CanReach("web1",    "admin")  .

% -----------------------------------------------------------------------
% Vulnerabilities (uncertain -- each host may or may not be vulnerable)
% -----------------------------------------------------------------------

Vulnerable("dmz")    :: 0.6.
Vulnerable("web1")   :: 0.7.
Vulnerable("web2")   :: 0.4.
Vulnerable("db")     :: 0.8.
Vulnerable("backup") :: 0.3.
Vulnerable("admin")  :: 0.5.

% -----------------------------------------------------------------------
% Derived relations
% -----------------------------------------------------------------------

% An attacker can pivot from host A to host B if there is a direct
% connection AND host B is vulnerable.
CanPivot(x, y) :- CanReach(x, y), Vulnerable(y).

% A host is compromised if the attacker can reach it by a chain of
% pivots from the entry point.
Compromised("entry").
Compromised(y) :- Compromised(x), CanPivot(x, y).

% -----------------------------------------------------------------------
% Sensors (uncertain -- each has a chance of missing a real intrusion)
% -----------------------------------------------------------------------

% A sensor fires if the host is compromised AND the sensor detects it,
% OR it fires spuriously (false positive).

DetectHit("sensor_dmz")    :: 0.85.
DetectHit("sensor_web1")   :: 0.85.
DetectHit("sensor_db")     :: 0.9.
DetectHit("sensor_admin")  :: 0.9.

FalsePositive("sensor_dmz")   :: 0.05.
FalsePositive("sensor_web1")  :: 0.05.
FalsePositive("sensor_db")    :: 0.02.
FalsePositive("sensor_admin") :: 0.02.

SensorFired("sensor_dmz")   :- Compromised("dmz"),   DetectHit("sensor_dmz").
SensorFired("sensor_web1")  :- Compromised("web1"),  DetectHit("sensor_web1").
SensorFired("sensor_db")    :- Compromised("db"),    DetectHit("sensor_db").
SensorFired("sensor_admin") :- Compromised("admin"), DetectHit("sensor_admin").

SensorFired("sensor_dmz")   :- FalsePositive("sensor_dmz").
SensorFired("sensor_web1")  :- FalsePositive("sensor_web1").
SensorFired("sensor_db")    :- FalsePositive("sensor_db").
SensorFired("sensor_admin") :- FalsePositive("sensor_admin").

% -----------------------------------------------------------------------
% Queries: prior probabilities (before any sensor observations)
% -----------------------------------------------------------------------

? Compromised("dmz").
? Compromised("web1").
? Compromised("db").
? Compromised("admin").

% -----------------------------------------------------------------------
% Observations: what the sensors actually reported
%   sensor_dmz   FIRED   (positive observation)
%   sensor_web1  FIRED   (positive observation)
%   sensor_db    SILENT  (negative observation)
%   sensor_admin SILENT  (negative observation)
% -----------------------------------------------------------------------

! SensorFired("sensor_dmz").
! SensorFired("sensor_web1").
! ~SensorFired("sensor_db").
! ~SensorFired("sensor_admin").

% -----------------------------------------------------------------------
% Queries: posterior probabilities (conditioned on sensor observations)
%
% Expected direction of updates:
%   Compromised("dmz")   -- higher: sensor fired, evidence of intrusion
%   Compromised("web1")  -- higher: sensor fired
%   Compromised("db")    -- lower: sensor was silent despite being sensitive
%   Compromised("admin") -- lower: sensor was silent
%   Compromised("backup")-- indirect: no sensor, but inferred from db
% -----------------------------------------------------------------------

? Compromised("dmz").
? Compromised("web1").
? Compromised("db").
? Compromised("admin").
? Compromised("backup").