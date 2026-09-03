# Probalog examples

Example programs for `#lang roulette/example/probalog`, a probabilistic
Datalog built on [Roulette](https://github.com/Smaran-Teja/roulette).
The engine, its language reference and its implementation notes live in
`roulette/roulette/example/probalog/`.

Install the language first, from the root of a roulette checkout on the
`visualizations` branch:

```
raco pkg install --auto roulette/ roulette-lib/
```

Then run any example:

```
racket basics/network-example.rkt
```

Every query in these files carries the answer it should produce, worked
out by hand where that is feasible. A comment that stops matching the
output is a regression signal.

Or all of them:

```
for f in */*.rkt; do echo "== $f"; racket "$f"; done
```

These are examples, not tests. The correctness suite — expected query
probabilities, every read error, every run-time error — lives with the
implementation, at `roulette/roulette/test/probalog.rkt`, and runs with
`raco test roulette/test/probalog.rkt`.

## `basics/`

| file                                                     | what it shows                                                                                       |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| [network-example.rkt](basics/network-example.rkt)        | the smallest complete program: probabilistic facts, a recursive rule, queries                       |
| [family-example.rkt](basics/family-example.rkt)          | the classic family-relations program, with one uncertain parentage record                           |
| [edge-cases.rkt](basics/edge-cases.rkt)                  | a reference for the whole surface syntax: nullary predicates, numeric constants, layout, projection |

## `models/`

Realistic models, each ending in a set of observations and posteriors.

| file                                       | what it shows                                                                                    |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| [alarm.rkt](models/alarm.rkt)              | Pearl's burglary/earthquake network: nullary predicates, CPTs as noisy-or, **explaining away**    |
| [smokers.rkt](models/smokers.rkt)          | "friends and smokers": recursion around a cyclic relation, and how to write a probabilistic rule |
| [observation.rkt](models/observation.rkt)  | intrusion detection with unreliable sensors: false positives and false negatives in one model    |

## `semantics/`

Why the engine computes what it computes.

| file                                          | what it shows                                                                                       |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| [correlation.rkt](semantics/correlation.rkt)  | the disjoint-sum problem: seven programs with hand-computable answers, next to what assuming independence would give |
| [cycles.rkt](semantics/cycles.rkt)            | recursion in every shape: cyclic graphs, self-loops, mutual recursion, non-linear recursion         |

## `ported/`

Standard examples from Soufflé and ProbLog, brought over unchanged
where the language allows it. Each file notes what had to be adapted,
which is often the most informative part: probalog puts probabilities
on facts rather than rules, and has no negation, no disequality and no
annotated disjunctions.

| file                                                            | ported from                                                            | what it shows                                                                          |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| [souffle-points-to.rkt](ported/souffle-points-to.rkt)           | Soufflé's tutorial (Andersen's analysis, the core of Doop)             | probabilistic program analysis: unresolved reflection and virtual dispatch as confidences, and why two candidates are *not* an exclusive choice here |
| [souffle-same-generation.rkt](ported/souffle-same-generation.rkt) | the classic `sg` benchmark, in Soufflé's test suite                    | the recursive atom in the middle of the body — bindings flowing in from `up` and out through `down` |
| [problog-biomine.rkt](ported/problog-biomine.rkt)               | ProbLog's flagship Biomine application                                 | connection probability in a biological network: exact 0.4153 against 0.5569 from treating paths as independent |
| [problog-genetics.rkt](ported/problog-genetics.rkt)             | ProbLog's genetics/bloodtype examples                                  | a pedigree where `:: 0.5` *is* meiosis; recovers the textbook 1/4 recurrence risk and 2/3 carrier probability |
| [problog-epidemic.rkt](ported/problog-epidemic.rkt)             | ProbLog's epidemic / viral-marketing examples                          | unrolling time without arithmetic, contact tracing backwards from a positive test        |

Two ProbLog staples are deliberately absent. The sprinkler/grass
network is the same noisy-or shape as [alarm.rkt](models/alarm.rkt),
which already covers it. A hidden Markov model is not expressible at
all: mutually exclusive states need negation or annotated
disjunctions, so [problog-epidemic.rkt](ported/problog-epidemic.rkt)
uses a monotone process instead, and says why.

## `library/`

| file                            | what it shows                                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| [api.rkt](library/api.rkt)      | probalog from Racket: the database as a symbolic set, set operations returning *distributions*, `observe-guard`, `run-datalog` |

## `bench/`

| file                                                     | what it shows                                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [probalog-examples.rkt](bench/probalog-examples.rkt)     | four generated program families with per-phase timing instrumentation                      |
| [probalog-plot.rkt](bench/probalog-plot.rkt)             | where the time goes: matching, guard construction, fixpoint equality, indexing, unions     |
| [compare-problog.sh](bench/compare-problog.sh)           | sets up ProbLog in a local virtualenv and runs the comparison — the entry point            |
| [compare-problog.py](bench/compare-problog.py)           | probalog against ProbLog on matched programs: wall time, and whether they agree            |
| [compare-souffle.sh](bench/compare-souffle.sh)           | the same against Soufflé — the entry point                                                 |
| [compare-souffle.py](bench/compare-souffle.py)           | probalog against Soufflé, run with and without probability annotations                     |

`probalog-plot.rkt` opens a plot window, and requiring it runs the
benchmarks first.

### Comparing against ProbLog

`compare-problog.py` generates the same model in both syntaxes, runs
both systems, and checks the answers against each other and against a
Monte Carlo simulation. ProbLog is a Python package, so the wrapper
script installs it into `bench/.venv` and runs the comparison:

```
./bench/compare-problog.sh --quick
```

The virtualenv is built once and reused, so only the first run pays
the install (about 13 seconds). Arguments pass straight through:

```
./bench/compare-problog.sh                            # every suite
./bench/compare-problog.sh dag smokers --timeout 120  # named suites
./bench/compare-problog.sh chordring --verify         # add Monte Carlo
./bench/compare-problog.sh --rebuild                  # reinstall
```

Two things it found, on one machine with ProbLog 2.2.10:

**Probalog agreed with ProbLog on every program tested**, and was
right where ProbLog was wrong. ProbLog's *default* knowledge compiler
is dsharp, and on the 16-node chorded ring it reports `13659.889` as a
probability. Probalog gives 0.938658, ProbLog's SDD backend gives
0.9386584, and a 2M-trial Monte Carlo gives 0.9388. Hence the `pysdd`
install above and the `-k sdd` this script passes; `--backend ddnnf`
reproduces the bad answer.

**Performance splits by program shape**, and not in one direction:

| workload              | ProbLog (sdd) | probalog |                       |
| --------------------- | -------------: | --------: | --------------------- |
| layered DAG (7,5)     |        36.09s |    1.03s | probalog 35x faster   |
| layered DAG (6,6)     |       110.63s |    2.42s | probalog 46x faster   |
| chorded ring, n=16    |         0.08s |    3.09s | probalog 39x slower   |
| smokers ring, n=16    |         0.08s |   67.59s | probalog 836x slower  |
| smokers ring, n=20    |         0.12s |  timeout | —                     |

Probalog wins on wide, acyclic, heavily-converging derivation — the
case its BDD guards and `for/sym-set/fast` merging were built for, and
where SDD compilation blows up instead. It loses, exponentially, on
recursion through cycles: the smokers ring costs 0.95s at 12 people
and 18.8s at 15, while ProbLog stays flat at 0.08s.

That split follows from the architecture. Probalog carries symbolic
guards *through* the Datalog fixpoint, so every round accumulates
redundant disjuncts and needs solver calls to decide it has converged.
ProbLog separates the phases: ground first with no probabilistic
reasoning, then compile once and do weighted model counting. Cycles
cost probalog on every round and cost ProbLog only once.

### Comparing against Soufflé

```
brew install souffle
./bench/compare-souffle.sh --quick
```

Soufflé is pure Datalog with no notion of probability, so this runs
probalog *twice* on each program: once with facts left unannotated
(probability 1, which produces concrete `#t` guards — probalog doing
plain Datalog) and once with every fact at `:: 0.5`. Same facts, same
rules, same fixpoint, same derived relation. The only difference is
whether the guards are symbolic, which isolates **the price of
uncertainty** from every other cost.

Two results, across five program families and 20 configurations:

**probalog@1 derived exactly the relation Soufflé did, every time** —
up to 5461 tuples. Since the suites include `sg` and Andersen's
points-to, that is a decent check of the Datalog core against a mature
engine.

**What probability costs depends entirely on program shape:**

| suite      | relation | probalog@1 | probalog@0.5 | cost of probability |
| ---------- | --------: | ---------: | ------------: | ------------------- |
| pointsto (16) |      289 |      0.48s |         0.64s | 1.3x                |
| sg (depth 6)  |     5461 |      0.63s |         1.36s | 2.2x                |
| ring (60)     |     3600 |      1.02s |         1.63s | 1.6x                |
| dag (6,6)     |      613 |      0.53s |         2.19s | 4.2x                |
| chordring (16)|      256 |      0.50s |         3.62s | 7.3x                |
| chordring (20)|      400 |      0.42s |       timeout | —                   |

Chains, trees and DAGs are cheap: points-to and same-generation pay
almost nothing for going probabilistic, even at 5461 tuples. Dense
cyclic graphs are where it goes wrong, and the last row is the clearest
statement of it — probalog computes all 400 tuples of that relation in
0.42s with certain facts and cannot finish in two minutes with
uncertain ones. Nothing changed but the guards.

Note that probalog@1 is essentially flat and startup-dominated
throughout (~0.3s of the time is Racket booting), so the Datalog core
itself is not what costs. Soufflé runs at 0.04–0.06s here, also mostly
startup; `souffle -c` compiles to C++ and would widen the gap further.

## Reading the output

A query prints as a distribution over `#t` and `#f`:

```
Path("a", "c"): #<pmf: [#t 0.3] [#f 0.7]>
```

unless the answer is certain, in which case it prints as `#t` or `#f`
alone. So `#f` means "provably never derivable, given the facts, the
rules and every observation so far", not "probability rounded to zero".
