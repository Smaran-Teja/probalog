#lang roulette/example/disrupt

;; Using probalog from Racket.
;;
;; A probalog module provides its saturated database as
;; `probalog-result`, so anything the `?`/`!` syntax can't say can be
;; said here instead: the database as a symbolic set, set operations
;; whose results are themselves distributions, conditioning on an
;; arbitrary formula, and building a program programmatically.
;;
;; Written in `roulette/example/disrupt` rather than plain `racket`,
;; since `query`, `observe!` and the symbolic operators come from
;; there.

(require "../basics/network-example.rkt"
         roulette/example/probalog/probalog-core
         roulette/example/probalog/probalog-set-equal)

;; network-example.rkt is the two-edge chain Edge("a","b") :: 0.5,
;; Edge("b","c") :: 0.6 with transitive Path. Requiring it runs it, so
;; its own queries print first.

(define (edge from to) (fact 'Edge (list from to)))
(define (path from to) (fact 'Path (list from to)))

(define (report label v) (printf "~a: ~a\n" label v))
(define (heading s) (printf "\n-- ~a ---------------------------\n" s))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The database as a value

(heading "the saturated database")

;; Iterating a sym-set gives (fact, guard) pairs. `x$0` is the coin
;; flip for Edge("a","b") and `x$1` the one for Edge("b","c"), in
;; declaration order. Path("a","c") is their conjunction -- a formula,
;; not a number, which is what makes shared evidence come out right.
(for ([(f guard) probalog-result])
  (printf "  ~a\n    guard: ~a\n" f guard))

;; `query-fact` is what a `?` statement expands to.
(newline)
(report "query-fact Path(a,c)" (query-fact probalog-result (path "a" "c")))

;; `set-member?` is the layer underneath: the raw guard.
(report "guard for Path(a,c)" (set-member? probalog-result (path "a" "c")))

;; A fact never derived has guard #f, hence `?` printing #f for it.
(report "guard for Path(c,a)" (set-member? probalog-result (path "c" "a")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set operations, and questions `?` can't ask

(heading "the database as a set")

;; How big is the database? That depends on which base facts held, so
;; `set-count` is symbolic and querying it gives a distribution over
;; sizes: neither edge (0.2) leaves 0 facts, either one alone leaves
;; 2, both (0.3) leave all 5.
(report "distribution over database size" (query (set-count probalog-result)))

;; A conjunctive query, which `?` can't express since it takes one fact.
(define both-hops (set (path "a" "b") (path "b" "c")))
(report "P(both single-hop paths present)"
        (query (subset? both-hops probalog-result)))

(report "how many of the two are present"
        (query (set-count (set-intersect probalog-result both-hops))))

(report "P(database empty)" (query (set-empty? probalog-result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Conditioning on a formula

(heading "observe-guard")

;; `!` and `! ~` can only say one fact holds or doesn't. Disjunctive
;; evidence needs the formula built by hand. Here "at least one edge
;; is up" rules out only the both-absent world (0.2), so P(Path(a,c))
;; goes 0.3 -> 0.375.
(define g-ab (set-member? probalog-result (edge "a" "b")))
(define g-bc (set-member? probalog-result (edge "b" "c")))

(report "before: P(Path(a,c))" (query-fact probalog-result (path "a" "c")))
(observe-guard (|| g-ab g-bc))
(report "after observing (a->b or b->c): P(Path(a,c))"
        (query-fact probalog-result (path "a" "c")))

;; `observe-fact` and `observe-not-fact` are what `!` and `! ~`
;; expand to. Both check the observation is possible first, so an
;; impossible one errors rather than dividing by zero.
(observe-fact probalog-result (edge "b" "c"))
(report "after also observing b->c: P(Path(a,c))"
        (query-fact probalog-result (path "a" "c")))

;; With b->c certain, Path(a,c) holds exactly when a->b does, and the
;; earlier disjunctive evidence is subsumed.
(report "P(Edge(a,b))" (query-fact probalog-result (edge "a" "b")))
(report "distribution over database size" (query (set-count probalog-result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Building a program in Racket

(heading "run-datalog directly")

;; The surface syntax is a front end for `run-datalog`, which takes
;; (fact . probability) pairs and rules. Worth using when the program
;; is generated rather than written -- see bench/probalog-examples.rkt.
;;
;;   Edge(0, 1) :: 0.8.            (cons (fact 'Edge '(0 1)) 0.8)
;;   Reach(x, y) :- Edge(x, y).    (rule (fact 'Reach '(x y))
;;                                       (list (fact 'Edge '(x y))))
;;
;; Variables are plain symbols in argument position -- that's what
;; `match-fact` keys off of, and why the surface syntax insists
;; constants be written as strings or numbers.

(define n 6)   ;; a ring 0 -> 1 -> ... -> 5 -> 0

(define ring-facts
  (for/list ([i (in-range n)])
    (cons (fact 'Edge (list i (modulo (add1 i) n))) 0.8)))

(define ring-rules
  (list (rule (fact 'Reach (list 'x 'y))
              (list (fact 'Edge (list 'x 'y))))
        (rule (fact 'Reach (list 'x 'z))
              (list (fact 'Reach (list 'x 'y))
                    (fact 'Edge (list 'y 'z))))))

(define ring (run-datalog ring-facts ring-rules))

;; Reaching a node k hops away needs all k edges, so 0.8^k. Going all
;; the way round to yourself takes all six.
(for ([k (in-range n)])
  (report (format "P(Reach(0, ~a)), ~a hop~a"
                  (modulo k n) (if (zero? k) n k) (if (= k 1) "" "s"))
          (query-fact ring (fact 'Reach (list 0 (modulo k n))))))

;; All 36 pairs are derivable, but only when every edge is up
;; (0.8^6 = 0.262). Break the ring anywhere and it collapses to
;; whatever a path still connects -- one missing edge leaves a chain
;; of 15 pairs, and so on down to 0. A distribution over the size of a
;; relation, which is what having the database as a symbolic value
;; buys you.
(report "reachable pairs in the ring"
        (query (set-count (set-intersect
                           ring
                           ;; `set` is a macro over literal elements,
                           ;; so a computed set uses for*/sym-set,
                           ;; whose body yields element and guard.
                           (for*/sym-set ([i (in-range n)] [j (in-range n)])
                             (values (fact 'Reach (list i j)) #t))))))
