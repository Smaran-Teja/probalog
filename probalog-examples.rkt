#lang roulette/example/disrupt
(require roulette/example/probalog/probalog-core
         roulette/example/probalog/probalog-set-equal)
(provide benchmark-results aggregate-timing run-benchmarks)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program generators
;;
;; Each returns (values facts rules), where facts is a list of
;; (cons fact probability). They're parameterized so the size can be
;; tuned, but each benchmark below picks one fixed configuration.

;; A layered DAG: SRC -> L0_* -> ... -> L(layers-1)_* -> SINK, fully
;; connected between adjacent layers. Every SRC->SINK path has the
;; same length, and there are width^layers distinct simple paths, so
;; this stresses guard construction over many converging derivations.
(define (make-layered-dag layers width [edge-prob 0.9])
  (define (node l i) (format "L~a_~a" l i))
  (define facts
    (append
     (for/list ([j (in-range width)])
       (cons (fact 'Edge (list "SRC" (node 0 j))) edge-prob))
     (for*/list ([i (in-range (sub1 layers))]
                 [j (in-range width)]
                 [k (in-range width)])
       (cons (fact 'Edge (list (node i j) (node (add1 i) k))) edge-prob))
     (for/list ([j (in-range width)])
       (cons (fact 'Edge (list (node (sub1 layers) j) "SINK")) edge-prob))))
  (define rules
    (list (rule (fact 'Path (list 'x 'y))
                (list (fact 'Edge (list 'x 'y))))
          (rule (fact 'Path (list 'x 'z))
                (list (fact 'Path (list 'x 'y))
                      (fact 'Edge (list 'y 'z))))))
  (values facts rules))

;; A ring of n nodes with chords to the node k ahead. Every node
;; reaches every other, and the cycles mean facts are re-derived many
;; ways, so this stresses fixpoint detection: guards keep accumulating
;; syntactically redundant disjuncts that only a semantic check can
;; see through.
(define (make-cyclic-ring n [chord 3] [edge-prob 0.85])
  (define (node i) (format "N~a" i))
  (define facts
    (append
     (for/list ([i (in-range n)])
       (cons (fact 'Edge (list (node i) (node (modulo (add1 i) n)))) edge-prob))
     (for/list ([i (in-range n)])
       (cons (fact 'Edge (list (node i) (node (modulo (+ i chord) n)))) edge-prob))))
  (define rules
    (list (rule (fact 'Reach (list 'x 'y))
                (list (fact 'Edge (list 'x 'y))))
          (rule (fact 'Reach (list 'x 'z))
                (list (fact 'Reach (list 'x 'y))
                      (fact 'Edge (list 'y 'z))))))
  (values facts rules))

;; A balanced binary ancestry tree with several derived relations
;; layered on top. Unlike the graph benchmarks this has many distinct
;; predicates and rules with three body clauses, so it stresses the
;; join across predicates rather than deep recursion.
(define (make-family depth [parent-prob 0.95])
  (define (person i) (format "P~a" i))
  (define size (sub1 (expt 2 depth)))
  (define facts
    (append
     ;; parent i -> children 2i+1, 2i+2
     (for*/list ([i (in-range size)]
                 [c (in-list (list (+ (* 2 i) 1) (+ (* 2 i) 2)))]
                 #:when (< c size))
       (cons (fact 'Parent (list (person i) (person c))) parent-prob))
     ;; alternating genders, all certain
     (for/list ([i (in-range size)])
       (cons (fact (if (even? i) 'Male 'Female) (list (person i))) 1))))
  (define rules
    (list (rule (fact 'Ancestor (list 'x 'y))
                (list (fact 'Parent (list 'x 'y))))
          (rule (fact 'Ancestor (list 'x 'z))
                (list (fact 'Ancestor (list 'x 'y))
                      (fact 'Parent (list 'y 'z))))
          (rule (fact 'Grandfather (list 'x 'y))
                (list (fact 'Parent (list 'x 'z))
                      (fact 'Parent (list 'z 'y))
                      (fact 'Male (list 'x))))
          (rule (fact 'Grandmother (list 'x 'y))
                (list (fact 'Parent (list 'x 'z))
                      (fact 'Parent (list 'z 'y))
                      (fact 'Female (list 'x))))
          (rule (fact 'Son (list 'x 'y))
                (list (fact 'Parent (list 'y 'x))
                      (fact 'Male (list 'x))))
          (rule (fact 'Daughter (list 'x 'y))
                (list (fact 'Parent (list 'y 'x))
                      (fact 'Female (list 'x))))))
  (values facts rules))

;; A layered dependency graph where a package is vulnerable if any
;; dependency is, plus an audit relation that joins vulnerability
;; against maintenance status. Base facts have mixed probabilities,
;; so guards stay genuinely symbolic rather than collapsing.
(define (make-supply-chain layers width)
  (define (pkg l i) (format "pkg~a_~a" l i))
  (define facts
    (append
     ;; each package depends on two in the layer below
     (for*/list ([l (in-range (sub1 layers))]
                 [i (in-range width)]
                 [d (in-list (list i (modulo (add1 i) width)))])
       (cons (fact 'DependsOn (list (pkg l i) (pkg (add1 l) d))) 0.9))
     ;; leaves carry a direct vulnerability risk
     (for/list ([i (in-range width)])
       (cons (fact 'HasCVE (list (pkg (sub1 layers) i))) (if (even? i) 0.3 0.15)))
     ;; maintenance status, also uncertain
     (for*/list ([l (in-range layers)]
                 [i (in-range width)])
       (cons (fact 'Unmaintained (list (pkg l i))) 0.2))))
  (define rules
    (list (rule (fact 'Vulnerable (list 'p))
                (list (fact 'HasCVE (list 'p))))
          (rule (fact 'Vulnerable (list 'p))
                (list (fact 'DependsOn (list 'p 'q))
                      (fact 'Vulnerable (list 'q))))
          (rule (fact 'NeedsAudit (list 'p))
                (list (fact 'Vulnerable (list 'p))
                      (fact 'Unmaintained (list 'p))))))
  (values facts rules))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Benchmarks
;;
;; Each entry is (name thunk query-fact), where the thunk returns
;; (values facts rules) and query-fact is one fact to report the
;; probability of, as a sanity check that the run did something.

(define benchmarks
  (list
   (list "layered-dag"
         (lambda () (make-layered-dag 5 3))
         (fact 'Path (list "SRC" "SINK")))
   (list "cyclic-ring"
         (lambda () (make-cyclic-ring 12 3))
         (fact 'Reach (list "N0" "N6")))
   (list "family"
         (lambda () (make-family 5))
         (fact 'Ancestor (list "P0" "P30")))
   (list "supply-chain"
         (lambda () (make-supply-chain 5 4))
         (fact 'NeedsAudit (list "pkg0_0")))))

;; Runs one benchmark, returning
;; (name wall equal-time bindings-time guard-time union-time index-time).
;; Timings come from subtracting the exported accumulators before and
;; after (read-only access across modules is fine; set!-ing an imported
;; variable is not, which is why we subtract rather than reset).
(define (run-benchmark name make-program query-target)
  (define-values (facts rules) (make-program))
  (define equal-before total-my-hash-equal?-time)
  (define bindings-before total-find-bindings-time)
  (define guard-before total-guard-build-time)
  (define union-before total-set-union-time)
  (define index-before total-index-time)
  (define wall-start (current-inexact-monotonic-milliseconds))
  (define result (run-datalog facts rules))
  (define wall (- (current-inexact-monotonic-milliseconds) wall-start))
  (printf "~a: ~a facts, ~a rules, ~ams -- ~a: ~a\n"
          name (length facts) (length rules) wall
          query-target (query-fact result query-target))
  (flush-output)
  (list name wall
        (- total-my-hash-equal?-time equal-before)
        (- total-find-bindings-time bindings-before)
        (- total-guard-build-time guard-before)
        (- total-set-union-time union-before)
        (- total-index-time index-before)))

(define (run-benchmarks)
  (for/list ([b benchmarks])
    (run-benchmark (car b) (cadr b) (caddr b))))

;; Sums each timing category across every benchmark, as
;; (total-wall equal bindings guard union index).
(define (aggregate-timing results)
  (for/fold ([wall 0] [equal 0] [bindings 0] [guard 0] [union 0] [index 0])
            ([r results])
    (values (+ wall (list-ref r 1))
            (+ equal (list-ref r 2))
            (+ bindings (list-ref r 3))
            (+ guard (list-ref r 4))
            (+ union (list-ref r 5))
            (+ index (list-ref r 6)))))

(define benchmark-results (run-benchmarks))