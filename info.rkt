#lang info

;; general

(define name "probalog")
(define collection "probalog")
(define pkg-desc "Probabilistic Datalog with exact inference by knowledge compilation.")
(define version "0.0")
(define license 'Apache-2.0)

(define scribblings
  '(["scribblings/probalog.scrbl" (multi-page)]))

;; `extra` holds development tools that are not part of the language and
;; pull in heavier dependencies (plot), mirroring roulette's own layout.
(define test-omit-paths '("extra" "examples"))
(define compile-omit-paths '("extra"))

;; dependencies

;; `roulette-lib` alone: the only thing probalog takes from roulette is
;; the rsdd BDD layer that `guards.rkt` is built on. `pmf.rkt` supplies
;; the distribution type locally rather than borrowing disrupt's, which
;; would drag in the whole roulette package.
;;
;; `rackunit-lib` is a runtime dependency, not just a test one:
;; `guards.rkt` uses `require/expose` from it to reach BDD primitives
;; that roulette does not yet export.
(define deps
  '("base"
    "data-lib"
    "rackunit-lib"
    "roulette-lib"))

(define build-deps
  '("racket-doc"
    "scribble-lib"))
