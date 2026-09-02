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

## `library/`

| file                            | what it shows                                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| [api.rkt](library/api.rkt)      | probalog from Racket: the database as a symbolic set, set operations returning *distributions*, `observe-guard`, `run-datalog` |

## `bench/`

| file                                                     | what it shows                                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [probalog-examples.rkt](bench/probalog-examples.rkt)     | four generated program families with per-phase timing instrumentation                      |
| [probalog-plot.rkt](bench/probalog-plot.rkt)             | where the time goes: matching, guard construction, fixpoint equality, indexing, unions     |

`probalog-plot.rkt` opens a plot window, and requiring it runs the
benchmarks first.

## Reading the output

A query prints as a distribution over `#t` and `#f`:

```
Path("a", "c"): #<pmf: [#t 0.3] [#f 0.7]>
```

unless the answer is certain, in which case it prints as `#t` or `#f`
alone. So `#f` means "provably never derivable, given the facts, the
rules and every observation so far", not "probability rounded to zero".
