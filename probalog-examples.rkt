#lang roulette/example/disrupt
(require "probalog-core.rkt"
         "probalog-set-equal.rkt")
(provide run-sweep sanity-results full-results)

;; ---------------------------------------------------------------------
;; Example 1: simple two-hop path
;; ---------------------------------------------------------------------
(define ab (fact 'Edge (list "a" "b")))
(define bc (fact 'Edge (list "b" "c")))
(define path-xy (rule (fact 'Path (list 'x 'y))
                       (list (fact 'Edge (list 'x 'y)))))
(define path-xz
  (rule (fact 'Path (list 'x 'z))
        (list (fact 'Edge (list 'x 'y))
              (fact 'Edge (list 'y 'z)))))

(define path-facts (list (cons ab 0.8) (cons bc 0.8)))
(define path-rules (list path-xy path-xz))

(define path-result (run-datalog path-facts path-rules))

(printf "Path(a,c): ~a\n"
        (query (set-member? path-result (fact 'Path (list "a" "c")))))

;; ---------------------------------------------------------------------
;; Example 2: network with disjoint equal-length routes, a cycle, and
;; cross-predicate conjunction (Alert/Risky depend on Faulty as well
;; as Path).
;; ---------------------------------------------------------------------
(define A "A") (define B "B") (define C "C") (define D "D") (define E "E")

(define e-ab (fact 'Edge (list A B)))
(define e-ac (fact 'Edge (list A C)))
(define e-bd (fact 'Edge (list B D)))
(define e-cd (fact 'Edge (list C D)))
(define e-de (fact 'Edge (list D E)))
(define e-db (fact 'Edge (list D B)))   ;; cycle
(define f-c  (fact 'Faulty (list C)))
(define f-e  (fact 'Faulty (list E)))

(define net-path-base (rule (fact 'Path (list 'x 'y))
                             (list (fact 'Edge (list 'x 'y)))))
(define net-path-step (rule (fact 'Path (list 'x 'z))
                             (list (fact 'Path (list 'x 'y))
                                   (fact 'Edge (list 'y 'z)))))
(define alert-rule (rule (fact 'Alert (list 'x))
                          (list (fact 'Edge (list 'x 'y))
                                (fact 'Faulty (list 'y)))))
(define risky-rule (rule (fact 'Risky (list 'x))
                          (list (fact 'Path (list 'x 'y))
                                (fact 'Faulty (list 'y)))))

(define network-facts
  (list (cons e-ab 0.9) (cons e-ac 0.7) (cons e-bd 0.8)
        (cons e-cd 0.6) (cons e-de 0.95) (cons e-db 0.5)
        (cons f-c 0.3) (cons f-e 0.1)))
(define network-rules (list net-path-base net-path-step alert-rule risky-rule))

(define network-result (run-datalog network-facts network-rules))

(for ([q (list (fact 'Path (list A D))
               (fact 'Path (list A E))
               (fact 'Alert (list A))
               (fact 'Risky (list A)))])
  (printf "~a: ~a\n" q (query (set-member? network-result q))))

;; ---------------------------------------------------------------------
;; Example 3: diverging-route counterexample — two independent routes
;; of DIFFERENT lengths to the same fact.
;; ---------------------------------------------------------------------
(define N1 "N1") (define N2 "N2") (define N4 "N4")
(define N5 "N5") (define N6 "N6") (define N7 "N7")

(define diverge-e-short-1 (fact 'Edge (list N1 N2)))
(define diverge-e-short-2 (fact 'Edge (list N2 N4)))
(define diverge-e-long-1 (fact 'Edge (list N1 N5)))
(define diverge-e-long-2 (fact 'Edge (list N5 N6)))
(define diverge-e-long-3 (fact 'Edge (list N6 N7)))
(define diverge-e-long-4 (fact 'Edge (list N7 N4)))

(define diverge-path-base
  (rule (fact 'Path (list 'x 'y))
        (list (fact 'Edge (list 'x 'y)))))
(define diverge-path-step
  (rule (fact 'Path (list 'x 'z))
        (list (fact 'Path (list 'x 'y))
              (fact 'Edge (list 'y 'z)))))

(define diverge-facts
  (list (cons diverge-e-short-1 0.9) (cons diverge-e-short-2 0.9)
        (cons diverge-e-long-1 0.9) (cons diverge-e-long-2 0.9)
        (cons diverge-e-long-3 0.9) (cons diverge-e-long-4 0.9)))
(define diverge-rules (list diverge-path-base diverge-path-step))

(define diverge-result (run-datalog diverge-facts diverge-rules))

;; Correct answer (two independent routes, noisy-or):
;;   short: 0.9 * 0.9 = 0.81
;;   long:  0.9^4     = 0.6561
;;   combined: 1 - (1-0.81)*(1-0.6561) = 1 - 0.19*0.3439 ~ 0.934659
(printf "Path(N1,N4): ~a\n"
        (query (set-member? diverge-result (fact 'Path (list N1 N4)))))

;; ---------------------------------------------------------------------
;; Example 4 (PERFORMANCE / SPEED TEST): a layered DAG from a single
;; source to a single sink, fully connected between adjacent layers.
;; Every SRC->SINK path has the same length (layers + 1 hops); the
;; number of distinct simple paths is width^layers.
;;
;; Tune `perf-layers`/`perf-width` up to increase the stress;
;; width^layers grows fast, so start small and raise gradually.
;; ---------------------------------------------------------------------
(define perf-layers 5)   ;; number of intermediate layers between source and sink
(define perf-width 3)    ;; nodes per layer

(define (perf-node-name layer idx) (format "L~a_~a" layer idx))
(define perf-source "SRC")
(define perf-sink "SINK")
(define perf-edge-prob 0.9)

(define perf-facts
  (append
   (for/list ([j (in-range perf-width)])
     (cons (fact 'Edge (list perf-source (perf-node-name 0 j))) perf-edge-prob))
   (for*/list ([i (in-range (sub1 perf-layers))]
               [j (in-range perf-width)]
               [k (in-range perf-width)])
     (cons (fact 'Edge (list (perf-node-name i j) (perf-node-name (add1 i) k)))
           perf-edge-prob))
   (for/list ([j (in-range perf-width)])
     (cons (fact 'Edge (list (perf-node-name (sub1 perf-layers) j) perf-sink))
           perf-edge-prob))))

(define perf-rules
  (list (rule (fact 'Path (list 'x 'y))
              (list (fact 'Edge (list 'x 'y))))
        (rule (fact 'Path (list 'x 'z))
              (list (fact 'Path (list 'x 'y))
                    (fact 'Edge (list 'y 'z))))))

(printf "--- Performance test: ~a layers x ~a width (~a simple paths) ---\n"
        perf-layers perf-width (expt perf-width perf-layers))

(define perf-result (time (run-datalog perf-facts perf-rules)))
(printf "Path(SRC,SINK): ~a\n"
        (query (set-member? perf-result (fact 'Path (list perf-source perf-sink)))))

;; ---------------------------------------------------------------------
;; Example 5 (SWEEP): how much of total run time is spent inside
;; my-hash-equal? (the Z3-backed guard-equivalence check), as a
;; function of the layered-DAG performance test's `layers`/`width`.
;;
;; WARNING: the number of simple SRC->SINK paths is width^layers. The
;; grid below (layers up to 36, width up to 6) includes combinations
;; like layers=36, width=6 -> 6^36 paths, which is almost certainly
;; intractable — this may run for a very long time or effectively
;; hang on the larger combinations. Consider starting with the small
;; SANITY-CHECK grid further down, or shrinking the ranges below,
;; before running the full sweep.
;; ---------------------------------------------------------------------

;; Build the same kind of layered-DAG program as the performance test
;; above, but parameterized so the sweep can construct a fresh one for
;; each (layers, width) combination.
(define (make-sweep-program layers width)
  (define (node-name layer idx) (format "SW~a_~a" layer idx))
  (define source "SWEEP_SRC")
  (define sink "SWEEP_SINK")
  (define edge-prob 0.9)
  (define facts
    (append
     (for/list ([j (in-range width)])
       (cons (fact 'Edge (list source (node-name 0 j))) edge-prob))
     (for*/list ([i (in-range (sub1 layers))]
                 [j (in-range width)]
                 [k (in-range width)])
       (cons (fact 'Edge (list (node-name i j) (node-name (add1 i) k))) edge-prob))
     (for/list ([j (in-range width)])
       (cons (fact 'Edge (list (node-name (sub1 layers) j) sink)) edge-prob))))
  (define rules
    (list (rule (fact 'Path (list 'x 'y))
                (list (fact 'Edge (list 'x 'y))))
          (rule (fact 'Path (list 'x 'z))
                (list (fact 'Path (list 'x 'y))
                      (fact 'Edge (list 'y 'z))))))
  (values facts rules))

;; Runs one (layers, width) combo. Returns wall-elapsed plus a
;; breakdown of where that time went, via subtraction against the
;; exported timing accumulators (read-only access across modules is
;; fine; set!-ing an imported variable is not, which is why we
;; subtract rather than reset each to 0 before every run):
;;   - equal-time:    time in my-hash-equal? (the Z3 equivalence check)
;;   - bindings-time: time in find-bindings-prob/delta (unification/join)
;;   - guard-time:    time in set-add-guarded (guard construction)
;;   - union-time:    time in set-union (merging full/delta accumulators)
;; wall-elapsed - (sum of the above) is unaccounted-for overhead
;; (indexing, GC, misc bookkeeping).
(define (measure-timing layers width)
  (define-values (facts rules) (make-sweep-program layers width))
  (define equal-before total-my-hash-equal?-time)
  (define bindings-before total-find-bindings-time)
  (define guard-before total-guard-build-time)
  (define union-before total-set-union-time)
  (define wall-start (current-inexact-monotonic-milliseconds))
  (run-datalog facts rules)
  (define wall-elapsed (- (current-inexact-monotonic-milliseconds) wall-start))
  (values wall-elapsed
          (- total-my-hash-equal?-time equal-before)
          (- total-find-bindings-time bindings-before)
          (- total-guard-build-time guard-before)
          (- total-set-union-time union-before)))

;; Runs the sweep over the given layers/width value lists, printing
;; progress as it goes (useful since some combinations may be slow),
;; and returns a list of
;; (layers width wall-elapsed equal-time bindings-time guard-time union-time)
;; 7-tuples.
(define (run-sweep layers-values width-values)
  (for*/list ([layers layers-values]
              [width width-values])
    (printf "layers=~a width=~a ... " layers width)
    (flush-output)
    (define-values (wall-elapsed equal-time bindings-time guard-time union-time)
      (measure-timing layers width))
    (printf "wall=~ams equal?=~ams bindings=~ams guard=~ams union=~ams\n"
            wall-elapsed equal-time bindings-time guard-time union-time)
    (list layers width wall-elapsed equal-time bindings-time guard-time union-time)))

;; --- SANITY CHECK (run this first): a small, fast grid --------------
(define sanity-layers (list 1 2 3))
(define sanity-width (list 1 2 3))
(define sanity-results (run-sweep sanity-layers sanity-width))

;; --- FULL SWEEP: layers in [1,30] step 2, width in [1,3] step 1
;; (in-range end is exclusive, so 31/4 to include 29/3)
(define full-layers-values (for/list ([l (in-range 1 31 2)]) l)) ; 1 3 5 ... 29
(define full-width-values (for/list ([w (in-range 1 4 1)]) w))    ; 1 2 3

(define full-results (run-sweep full-layers-values full-width-values))

;; Plotting is done separately, in probalog-plot.rkt (plain #lang
;; racket) — see that file. Calling the `plot` library's functions from
;; inside a #lang roulette/example/disrupt module can fail with errors
;; like "struct->list: expected argument of type <non-opaque struct>",
;; since plot's internals assume ordinary Racket semantics that this
;; language's extensions (for symbolic/probabilistic execution) can
;; interfere with. Keeping measurement (this file) and visualization
;; (a plain-Racket file) separate avoids that entirely.