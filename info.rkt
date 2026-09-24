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

;; The only thing probalog needs from roulette is the rsdd BDD interface
;; that `guards.rkt` builds on -- `roulette/engine/rsdd`, which lives in
;; the roulette-lib package. Nothing here depends on the roulette or
;; disrupt surface languages.
(define deps
  '("base"
    "rackunit-lib"
    "roulette-lib"))

(define build-deps
  '("racket-doc"
    "rackunit-lib"
    "scribble-lib"
    ;; documentation only: probalog.scrbl cross-references disrupt, which
    ;; lives in the full roulette package rather than roulette-lib.
    "roulette"))
