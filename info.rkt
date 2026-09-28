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

;; probalog talks to rsdd directly through `rsdd.rkt`, so it needs the
;; shared library but none of roulette's Racket code. The `roulette-*`
;; platform packages carry nothing but a compiled rsdd; the name is
;; theirs, the dependency is not on roulette itself.
;;
;; `rackunit-lib` is a runtime dependency rather than a test-only one:
;; `hash-set.rkt` keeps its unit tests in the module body.
(define deps
  `(["roulette-x86_64-linux"   #:platform #rx"^x86_64-linux(?:-natipkg)?$"]
    ;; `darwin` as well as `macosx`, matching roulette-lib, which notes
    ;; that Nix on macOS reports the former.
    ["roulette-aarch64-macosx" #:platform #rx"^aarch64-((macosx)|(darwin))$"]
    ["roulette-x86_64-macosx"  #:platform #rx"^x86_64-((macosx)|(darwin))$"]
    ["roulette-x86_64-win32"   #:platform "win32\\x86_64"]
    "base"
    "data-lib"
    "rackunit-lib"))

(define build-deps
  '("racket-doc"
    "scribble-lib"))
