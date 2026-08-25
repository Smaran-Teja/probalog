#lang roulette/example/disrupt
(require "probalog-core.rkt"
         "probalog-set-equal.rkt")

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
(define perf-layers 40)   ;; number of intermediate layers between source and sink
(define perf-width 2)    ;; nodes per layer

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