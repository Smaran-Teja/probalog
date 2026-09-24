# Probalog examples and benchmarks

Example programs for `#lang roulette/example/probalog`, a probabilistic
Datalog built on [Roulette](https://github.com/Smaran-Teja/roulette),
together with benchmarks comparing it against ProbLog, cplint/PITA and
Soufflé.

Install the language first, from the root of a roulette checkout:

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

What the language computes, in cases where the answer is easy to get
wrong.

| file                                          | what it shows                                                                                       |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| [correlation.rkt](semantics/correlation.rkt)  | the disjoint-sum problem: seven programs with hand-computable answers, next to what assuming independence would give |
| [cycles.rkt](semantics/cycles.rkt)            | recursion in every shape: cyclic graphs, self-loops, mutual recursion, non-linear recursion         |

## `ported/`

Standard examples from Soufflé and ProbLog, brought over unchanged
where the language allows it. Each file notes what had to be adapted:
probalog puts probabilities on facts rather than rules, and has no
negation, no disequality and no annotated disjunctions.

| file                                                            | ported from                                                            | what it shows                                                                          |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| [souffle-points-to.rkt](ported/souffle-points-to.rkt)           | Soufflé's tutorial (Andersen's analysis, the core of Doop)             | probabilistic program analysis: unresolved reflection and virtual dispatch as confidences, and why two candidates are *not* an exclusive choice here |
| [souffle-same-generation.rkt](ported/souffle-same-generation.rkt) | the classic `sg` benchmark, in Soufflé's test suite                    | the recursive atom in the middle of the body — bindings flowing in from `up` and out through `down` |
| [problog-biomine.rkt](ported/problog-biomine.rkt)               | ProbLog's flagship Biomine application                                 | connection probability in a biological network: exact 0.4153 against 0.5569 from treating paths as independent |
| [problog-genetics.rkt](ported/problog-genetics.rkt)             | ProbLog's genetics/bloodtype examples                                  | a pedigree where `:: 0.5` *is* meiosis; recovers the textbook 1/4 recurrence risk and 2/3 carrier probability |
| [problog-epidemic.rkt](ported/problog-epidemic.rkt)             | ProbLog's epidemic / viral-marketing examples                          | unrolling time without arithmetic, contact tracing backwards from a positive test        |
| [psouffle-side-channel.rkt](ported/psouffle-side-channel.rkt)   | PSoufflé's `language_side_channel_mini` regression case                | which observed events a hidden value explains; ports unchanged, and reproduces PSoufflé's 0.6552 / 0.153 exactly |
| [psouffle-taint.rkt](ported/psouffle-taint.rkt)                 | PSoufflé's `language_taint_mini` regression case                       | taint reaching a sink by two routes; encodes away negation and a weighted rule, and reproduces PSoufflé's 0.2904 / 0.26129241 exactly |

PSoufflé's third bundled example, `language_symbolization_mini`, is not
here. It sums a numeric column with `TotalBytes = sum Bytes : {...}`,
and probalog has neither aggregates nor arithmetic, so there is no
faithful encoding — only a rewrite into a different program, which
would not be a port. The other two are exact: their answers match
PSoufflé's own output digit for digit.

Two ProbLog staples are deliberately absent. The sprinkler/grass
network is the same noisy-or shape as [alarm.rkt](models/alarm.rkt),
which already covers it. A hidden Markov model is not expressible at
all: mutually exclusive states need negation or annotated
disjunctions, so [problog-epidemic.rkt](ported/problog-epidemic.rkt)
uses a monotone process instead, and says why.

## `bench/`

| file                                                     | what it shows                                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [compare-problog.sh](bench/compare-problog.sh)           | sets up ProbLog in a local virtualenv and runs the comparison — the entry point            |
| [compare-problog.py](bench/compare-problog.py)           | probalog against ProbLog on matched programs: wall time, and whether they agree            |
| [compare-cplint.sh](bench/compare-cplint.sh)             | the same against cplint/PITA — the entry point                                             |
| [compare-cplint.py](bench/compare-cplint.py)             | probalog against PITA                                                                      |
| [compare-souffle.sh](bench/compare-souffle.sh)           | the same against Soufflé — the entry point                                                 |
| [compare-souffle.py](bench/compare-souffle.py)           | probalog against Soufflé, run with and without probability annotations                     |
| [compare-psouffle.sh](bench/compare-psouffle.sh)         | builds PSoufflé and CUDD from source, then runs the comparison — the entry point           |
| [compare-psouffle.py](bench/compare-psouffle.py)         | probalog against PSoufflé, the exact probabilistic Soufflé fork                            |
| [probalog-examples.rkt](bench/probalog-examples.rkt)     | four generated program families with per-phase timing instrumentation                      |
| [probalog-plot.rkt](bench/probalog-plot.rkt)             | a stacked-bar plot of that timing                                                          |

`compare-cplint.py` imports its program generators from
`compare-problog.py`, so those two run byte-identical models.
`compare-souffle.py` has its own, because Soufflé needs type
declarations and an output relation rather than a query — the program
shapes match but the code is separate. `compare-psouffle.py` imports
from `compare-souffle.py` in turn, so those two also match.

`probalog-plot.rkt` opens a plot window, and requiring it runs the
benchmarks first.

### Against ProbLog

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
./bench/compare-problog.sh dag smokers --timeout 30   # named suites
./bench/compare-problog.sh chordring --verify         # add Monte Carlo
./bench/compare-problog.sh --all-queries              # equal-work mode
./bench/compare-problog.sh --rebuild                  # reinstall
```

`--all-queries` matters for reading the numbers honestly. ProbLog and
PITA are goal-directed: they ground only what the query needs.
probalog computes the entire relation whatever you ask it. So the
default single-query mode charges probalog for work its opponents
never do, and `--all-queries` asks both for the whole relation
instead. On a 20-node ring:

|                | 1 query | all 400 tuples |
| -------------- | ------: | -------------: |
| probalog       |   0.70s |          0.84s |
| ProbLog (sdd)  |   0.12s |          0.17s |

probalog barely notices the extra 399 queries, because it had already
computed the whole relation and a marginal is a weighted count over a
diagram that already exists. ProbLog grows with the number of goals.
The gap closes slowly at these sizes; it is the trend that differs,
not yet the totals.

**Correctness.** probalog agreed with ProbLog on every program tested,
and disagreed only where ProbLog was wrong: ProbLog's *default*
knowledge compiler is dsharp, and on the 16-node chorded ring it
reports `13659.889` as a probability. probalog gives 0.938658,
ProbLog's SDD backend gives 0.9386584, and a 2M-trial Monte Carlo
gives 0.9388. Hence the `pysdd` install and the `-k sdd` this script
passes; `--backend ddnnf` reproduces the bad answer.

**Timings**, single query, 10s timeout:

| workload           | ProbLog (sdd) | probalog |
| ------------------ | ------------: | -------: |
| layered DAG (6,5)  |         1.45s |    1.07s |
| layered DAG (7,5)  |       timeout |    1.70s |
| layered DAG (6,6)  |       timeout |    4.64s |
| chorded ring n=16  |         0.12s |    1.06s |
| smokers ring n=13  |         0.09s |    0.87s |
| smokers ring n=14  |         0.08s |    0.79s |
| smokers ring n=15  |         0.07s |    0.82s |

probalog wins on the layered DAGs and loses everywhere else. ProbLog
times out from DAG (7,5) upward, where probalog is still under two
seconds.

Everywhere else probalog is flat but offset. The smokers ring does not
grow with n at all — 0.84 / 0.95 / 0.87 / 0.79 / 0.82s for n=10 through
15 — and roughly 0.3s of each of those is Racket starting up, so what
is left is a constant few hundred milliseconds against ProbLog's
constant 0.08s. Compiling guards as the derivation proceeds is what
makes those curves flat; the residual gap is a constant factor, not a
growth rate.

### Against cplint/PITA

```
./bench/compare-cplint.sh --quick
```

The wrapper installs SWI-Prolog's `cplint` pack on first run. Note
that cplint is Prolog rather than Datalog; every program here is in
the function-free fragment, so it does not bias the result, but PITA
is solving a more general problem than it needs to. PITA is also
goal-directed, so `--all-queries` applies here too.

**PITA agreed with probalog on all 19 configurations.** With ProbLog,
Soufflé and Monte Carlo, that is four independent confirmations.

| workload           |    PITA | probalog |
| ------------------ | ------: | -------: |
| ring (20)          |   0.17s |    0.79s |
| chorded ring (16)  |   0.19s |    1.07s |
| layered DAG (6,5)  | timeout |    1.27s |
| layered DAG (6,6)  | timeout |    4.23s |
| smokers ring (15)  |   0.22s |    0.80s |

PITA times out on the same DAGs ProbLog struggled with, from (6,5)
upward. On the smokers ring it is flat at ~0.20s across every size, as
is probalog at 0.80–0.89s. PITA is the closest comparison here: it
uses the same strategy of carrying a compiled representation through
the derivation rather than compiling an accumulated formula at the
end, which is why both curves are flat.

### Against Soufflé

```
brew install souffle
./bench/compare-souffle.sh --quick
```

Soufflé is pure Datalog with no notion of probability, so this runs
probalog *twice* on each program: once with facts left unannotated
(probability 1) and once with every fact at `:: 0.5`. Same facts, same
rules, same fixpoint, same derived relation — the only difference is
whether the probabilities are trivial, which isolates what uncertainty
costs from every other factor.

**probalog derived exactly the relation Soufflé did, every time** —
across five program families and 20 configurations, up to 22801 tuples.
Since the suites include `sg` and Andersen's points-to, that is a
reasonable check against a mature engine.

The `cost of probability` is probalog@0.5 divided by probalog@1:

| suite           | relation | prob cost |
| --------------- | -------: | --------: |
| pointsto (150)  |    22801 |  **1.1x** |
| sg (depth 7)    |    21845 |  **1.1x** |
| ring (120)      |    14400 |  **1.0x** |
| chordring (20)  |      400 |      3.9x |
| chordring (22)  |      484 |      6.5x |
| dag (7,5)       |      596 |      2.1x |
| dag (6,6)       |      613 |      6.6x |

On chains, trees and program analysis, probability is free —
points-to, same-generation and the 120-node ring cost the same at 0.5
as at 1, even at 22801 tuples. Dense cyclic graphs and wide converging
DAGs are where it is paid for.

probalog@1 is otherwise flat and startup-dominated (~0.3s of it is
Racket booting). Soufflé runs at 0.04–0.06s here, also mostly startup;
`souffle -c` compiles to C++ and would widen the gap further.

### Against PSoufflé

```
./bench/compare-psouffle.sh --quick
```

PSoufflé ([FMCAD 2026](https://doi.org/10.5281/zenodo.20091940), Li, Xia,
Adnan & Wang) extends Soufflé with exact probabilistic inference: it
instruments Soufflé's evaluation to build a derivation graph and
compiles it with CUDD. It is the closest comparison here, because it is
the only opponent that shares every property with probalog — Datalog
rather than Prolog, exact rather than approximate or bounded, and
bottom-up over the whole relation. Its query form `query(reach(_, _)).`
asks for every tuple, so there is no goal-direction correction to make.
It is also the closest algorithmically: forward knowledge compilation
into a BDD as the derivation proceeds, which is what probalog's guards
do.

The wrapper builds it from source, since it is a Soufflé fork rather
than a package, and builds CUDD 3.0.0 first because no package manager
carries it. Both are built under `~/.cache/probalog-psouffle` and
reused. They deliberately land outside this repository: CUDD's libtool
cannot handle whitespace in a path, and this repository normally lives
under one. Set `PROBALOG_PSOUFFLE_HOME` to move the build tree.

**Read these numbers with both handicaps in mind.** PSoufflé compiles
each program to a C++ binary first; that phase takes 5–7s and is
excluded below. probalog's column is a whole `racket` invocation, of
which **~0.47s is interpreter startup** before any inference begins.
Neither column is inference time, and they are biased in opposite
directions — for a single run of a program, probalog wins outright.

| suite           | PSoufflé | probalog | agree |
| --------------- | -------: | -------: | ----- |
| ring (120)      |    0.81s |    2.52s | yes |
| sg (depth 7)    |    1.26s |    0.91s | yes |
| pointsto (150)  |    1.26s |    2.53s | yes |
| dag (6,4)       |    0.78s |    0.52s | yes |
| dag (7,5)       |  timeout |    1.21s | -   |
| dag (6,6)       |  timeout |    4.15s | -   |
| chordring (22)  |    0.60s |    3.34s | **no** |

Within a small constant factor on the shapes where both finish, and
probalog is the one that still finishes on the wide DAGs. Subtracting
startup closes much of the rest: on ring(120) probalog's saturation is
1.84s of the 2.52s, and on ring(60) it is 0.30s against PSoufflé's
0.43s — faster.

Where PSoufflé is genuinely ahead the reasons are engineering rather
than algorithmic: it emits native C++, it has Soufflé's mature
relational engine (automatic minimal-index selection, B-trees tuned for
Datalog), and it runs CUDD with *dynamic* variable reordering where
probalog computes one static order and never revisits it.

**The chordring disagreement is unresolved.** PSoufflé and probalog
differ on every chorded-ring size. On an 8-node ring — smaller than any
in the table, and small enough to enumerate all 2^16 edge subsets — the
exact answer is `15/32 = 0.46875`, which is probalog's. PSoufflé reports
`0.4375`.

It reproduces on three edges. With `a->b`, `b->c` and `a->c` each at
0.5, `reach(a, c)` should be `P(ac or (ab and bc)) = 0.625`; PSoufflé
reports `0.5`, which is the probability of the direct edge alone.

I have not established whether this is an engine bug or a mistake in how
the harness writes the program. Two things argue against jumping to the
former: PSoufflé's own bundled taint example has a tuple with two
derivations and it computes that one exactly right (0.26129241 against a
hand-computed 0.261292407), and the paper PDF is not yet released, so
the intended way to express a recursive query may differ from what the
harness emits. Ruled out so far: the `--rewrite` and `--det-opt` flags
(the disagreement is identical without them), and the optional SDD
backend (absent from this build, but it is selected per program and
raises an error rather than degrading when missing). Treat the chordring
row as a question about the harness, not a claim about PSoufflé.

## Reading the output

A query prints as a distribution over `#t` and `#f`:

```
Path("a", "c"): #<pmf: [#t 0.3] [#f 0.7]>
```

unless the answer is certain, in which case it prints as `#t` or `#f`
alone. So `#f` means "provably never derivable, given the facts, the
rules and every observation so far", not "probability rounded to zero".
