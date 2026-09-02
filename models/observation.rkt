#lang roulette/example/probalog

% Network intrusion detection.
%
% An attacker starts at an entry point and pivots through the network
% by exploiting vulnerabilities. Sensors detect traffic but are
% unreliable: they miss real intrusions and fire spuriously. We
% observe which sensors fired, then ask which hosts were compromised.

% --- Topology (certain: we know the network layout) --------------------

CanReach("entry",   "dmz")    .
CanReach("dmz",     "web1")   .
CanReach("dmz",     "web2")   .
CanReach("web1",    "db")     .
CanReach("web2",    "db")     .
CanReach("db",      "backup") .
CanReach("web1",    "admin")  .

% --- Vulnerabilities ---------------------------------------------------

Vulnerable("dmz")    :: 0.6.
Vulnerable("web1")   :: 0.7.
Vulnerable("web2")   :: 0.4.
Vulnerable("db")     :: 0.8.
Vulnerable("backup") :: 0.3.
Vulnerable("admin")  :: 0.5.

% --- Attack propagation ------------------------------------------------

CanPivot(x, y) :- CanReach(x, y), Vulnerable(y).

Compromised("entry").
Compromised(y) :- Compromised(x), CanPivot(x, y).

% --- Sensors -----------------------------------------------------------
% A sensor fires if the host is compromised and it detects it, or if
% it fires spuriously.

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

% --- Priors ------------------------------------------------------------

? Compromised("dmz").
? Compromised("web1").
? Compromised("db").
? Compromised("admin").

% --- What the sensors reported -----------------------------------------

! SensorFired("sensor_dmz").
! SensorFired("sensor_web1").
! ~SensorFired("sensor_db").
! ~SensorFired("sensor_admin").

% --- Posteriors --------------------------------------------------------
% dmz and web1 rise (their sensors fired); db and admin fall (silent
% sensors, and sensitive ones); backup is inferred indirectly from db,
% with no sensor of its own.

? Compromised("dmz").
? Compromised("web1").
? Compromised("db").
? Compromised("admin").
? Compromised("backup").
