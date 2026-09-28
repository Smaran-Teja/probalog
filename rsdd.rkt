#lang racket/base

;; FFI bindings to rsdd's BDD builder, and weighted model counting over
;; the diagrams it produces.
;;
;; This is the whole of probalog's interface to the outside world. It was
;; adapted from roulette's `roulette-lib/engine/rsdd.rkt`, cut down to what
;; `guards.rkt` needs: no inference engine and no Rosette terms. The
;; semiring abstraction is kept -- weighted model counting is the same
;; traversal whatever the weights mean, and the alternatives are useful
;; (gradients, MPE, log-space) even though probalog only uses reals.
;;
;; The shared library itself still comes from the `roulette-*` platform
;; packages, which carry nothing but a compiled rsdd.

(provide (struct-out semiring) make-semiring
         semiring-zero semiring-one
         boolean-semiring number-semiring log-semiring
         expectation-semiring polynomial-semiring
         mk-bdd-manager-default-order free-bdd-manager
         rsdd-label rsdd-var
         rsdd-and rsdd-or rsdd-not rsdd-equal?
         rsdd-true? rsdd-false?
         make-rsdd-true make-rsdd-false
         rsdd-nodes rsdd-num-recursive-calls
         wmc free-weight-cache)

(require ffi/unsafe
         ffi/unsafe/define
         racket/match
         data/gvector)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FFI prelude

(define rsdd-ffi-lib (ffi-lib "librsdd"))

(define-ffi-definer define-rsdd rsdd-ffi-lib)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The builder
;;
;; A manager owns every diagram made from it. Nothing here may outlive
;; its builder: an operation on a node whose manager has been freed
;; faults in Rust rather than raising.

(define-cpointer-type _rsdd_bdd_builder)
(define-cpointer-type _rsdd_bdd_ptr)

(define-rsdd mk-bdd-manager-default-order
  (_fun _int64 -> _rsdd_bdd_builder)
  #:c-id mk_bdd_manager_default_order)

(define-rsdd free-bdd-manager
  (_fun _rsdd_bdd_builder -> _void)
  #:c-id free_bdd_manager)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Variables and constants

;; Labels are handed out sequentially from 0, which is what lets the
;; weight map be a gvector indexed by label.
(define-rsdd rsdd-label
  (_fun _rsdd_bdd_builder -> _int64)
  #:c-id bdd_new_label)

(define-rsdd bdd-var
  (_fun _rsdd_bdd_builder _int64 _stdbool -> _rsdd_bdd_ptr)
  #:c-id bdd_var)

;; Always the positive literal; negation is a separate operation.
(define (rsdd-var builder label) (bdd-var builder label #t))

(define-rsdd make-rsdd-true
  (_fun _rsdd_bdd_builder -> _rsdd_bdd_ptr) #:c-id bdd_true)
(define-rsdd make-rsdd-false
  (_fun _rsdd_bdd_builder -> _rsdd_bdd_ptr) #:c-id bdd_false)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Operations

(define-rsdd rsdd-and
  (_fun _rsdd_bdd_builder _rsdd_bdd_ptr _rsdd_bdd_ptr -> _rsdd_bdd_ptr)
  #:c-id bdd_and)
(define-rsdd rsdd-or
  (_fun _rsdd_bdd_builder _rsdd_bdd_ptr _rsdd_bdd_ptr -> _rsdd_bdd_ptr)
  #:c-id bdd_or)
(define-rsdd rsdd-not
  (_fun _rsdd_bdd_builder _rsdd_bdd_ptr -> _rsdd_bdd_ptr)
  #:c-id bdd_negate)

;; Diagrams are canonical, so equivalence is a comparison rather than a
;; search.
(define-rsdd rsdd-equal?
  (_fun _rsdd_bdd_builder _rsdd_bdd_ptr _rsdd_bdd_ptr -> _stdbool)
  #:c-id bdd_eq)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Inspection

(define-rsdd rsdd-true?
  (_fun _rsdd_bdd_ptr -> _stdbool) #:c-id bdd_is_true)
(define-rsdd rsdd-false?
  (_fun _rsdd_bdd_ptr -> _stdbool) #:c-id bdd_is_false)
(define-rsdd rsdd-neg?
  (_fun _rsdd_bdd_ptr -> _stdbool) #:c-id bdd_is_neg)
(define-rsdd rsdd-low
  (_fun _rsdd_bdd_ptr -> _rsdd_bdd_ptr) #:c-id bdd_low)
(define-rsdd rsdd-high
  (_fun _rsdd_bdd_ptr -> _rsdd_bdd_ptr) #:c-id bdd_high)
(define-rsdd rsdd-topvar
  (_fun _rsdd_bdd_ptr -> _int64) #:c-id bdd_topvar)
(define-rsdd rsdd-nodes
  (_fun _rsdd_bdd_ptr -> _size) #:c-id bdd_count_nodes)

;; Every apply call rsdd has made on this builder. The one number that
;; tracks how much work inference actually did.
(define-rsdd rsdd-num-recursive-calls
  (_fun _rsdd_bdd_builder -> _size)
  #:c-id bdd_num_recursive_calls)

;; Each node carries one scratch word, which `wmc` memoises into.
(define-rsdd rsdd-scratch
  (_fun _rsdd_bdd_ptr _gcpointer -> _gcpointer) #:c-id bdd_scratch)
(define-rsdd rsdd-set-scratch!
  (_fun _rsdd_bdd_ptr _gcpointer -> _void) #:c-id bdd_set_scratch)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Semirings
;;
;; What the weights on a diagram mean, and how to combine them. `wmc`
;; only ever adds along a node's two branches and multiplies down an
;; edge, so swapping the semiring reinterprets the same traversal:
;; probabilities with (+, *), satisfiability with (or, and), log-space
;; with (logsumexp, +), gradients with the expectation semiring.
;;
;; Zero and one come from calling the operations with no arguments,
;; which is why `make-semiring` lifts fixed-arity operations to
;; variadic ones carrying their identity.

(struct semiring (predicate add mul)
  #:property prop:procedure 0)

(define (semiring-zero s) ((semiring-add s)))
(define (semiring-one s)  ((semiring-mul s)))

(define (lift-op unit op)
  (case-lambda
    [() unit]
    [args (foldl op unit args)]))

(define (make-semiring p zero add one mul)
  (semiring p (lift-op zero add) (lift-op one mul)))

;; Probabilities. What probalog uses.
(define number-semiring (semiring number? + *))

;; Whether any model exists at all, ignoring weights.
(define boolean-semiring
  (make-semiring boolean?
                 #f (lambda (a b) (or a b))
                 #t (lambda (a b) (and a b))))

;; The same counts in log space, where a long chain of multiplications
;; will not underflow.
(define log-add
  (case-lambda
    [() -inf.0]
    [args (log (apply + (map exp args)))]))
(define log-semiring (semiring real? log-add +))

;; Carries a probability alongside its derivative, so one traversal
;; yields both the marginal and its gradient.
(define expectation-semiring
  (make-semiring
   (lambda (v) (and (list? v) (= 2 (length v)) (andmap real? v)))
   (list 0 0)
   (match-lambda**
    [((list p u) (list q v)) (list (+ p q) (+ u v))])
   (list 1 0)
   (match-lambda**
    [((list p u) (list q v)) (list (* p q) (+ (* p v) (* q u)))])))

;; Coefficient lists over another semiring, for counting by size or
;; tracking a marginal as a polynomial in one fact's probability.
(define (polynomial-semiring semi)
  (match-define (semiring predicate add mul) semi)
  (define (polynomial? v) (and (list? v) (andmap predicate v)))
  (define (polynomial-add p1 p2)
    (let go ([p1 p1] [p2 p2])
      (match* (p1 p2)
        [('() '()) '()]
        [('() p2) p2]
        [(p1 '()) p1]
        [((cons c1 r1) (cons c2 r2)) (cons (add c1 c2) (go r1 r2))])))
  (define (polynomial-mul p1 p2)
    (cond
      [(and (null? p1) (null? p2)) '()]
      [else
       (define result (make-vector (sub1 (+ (length p1) (length p2)))
                                   (semiring-zero semi)))
       (for ([c1 (in-list p1)] [k (in-naturals)]
             #:when #t
             [c2 (in-list p2)] [l (in-naturals)])
         (define i (+ k l))
         (vector-set! result i (add (vector-ref result i) (mul c1 c2))))
       (vector->list result)]))
  (make-semiring polynomial?
                 '() polynomial-add
                 (list (mul)) polynomial-mul))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Weighted model counting

;; The weight of `val` under `weights`: a gvector indexed by label
;; holding `(cons false-weight true-weight)`. With the default semiring
;; those weights are probabilities and this is the probability that
;; `val` holds; under another semiring they are whatever that semiring
;; measures, and the weight map must hold its elements rather than
;; reals.
;;
;; A node's value is memoised in its scratch cell, as a pair holding the
;; results for both polarities -- a negated pointer denotes the same node
;; read the other way round, so the two share a cell. `cache` is a box of
;; the cells allocated, since immobile cells are not garbage collected;
;; `free-weight-cache` releases them.
;;
;; SHARP EDGE: nothing invalidates the memo, so a result is only valid
;; while `weights` is unchanged. That holds for probalog, where
;; conditioning conjoins evidence rather than reweighting.
;;
;; The memo is not keyed by semiring either, so counting one diagram
;; under two of them returns the first one's answers for every shared
;; node. Use a fresh builder per semiring, or clear the scratch cells
;; in between.
(define (wmc val weights cache [semi number-semiring])
  (match-define (semiring _ add mul) semi)
  (define zero (semiring-zero semi))
  (define one (semiring-one semi))
  (let go ([val val])
    (define neg? (rsdd-neg? val))
    (define-values (self other)
      (let* ([result (rsdd-scratch val #f)]
             [result (and result (ptr-ref result _racket 0))])
        (cond
          [(not result) (values #f #f)]
          [neg? (values (cdr result) (car result))]
          [else (values (car result) (cdr result))])))
    (cond
      [self self]
      [(rsdd-true? val) (if neg? zero one)]
      [(rsdd-false? val) (if neg? one zero)]
      [else
       (define w (gvector-ref weights (rsdd-topvar val)))
       (define result
         (add (mul (car w) (go (rsdd-low val)))
              (mul (cdr w) (go (rsdd-high val)))))
       (define scratch
         (malloc-immobile-cell
          (if neg? (cons other result) (cons result other))))
       (set-box! cache (cons scratch (unbox cache)))
       (rsdd-set-scratch! val scratch)
       result])))

(define (free-weight-cache cache)
  (for ([ptr (in-list (unbox cache))])
    (free-immobile-cell ptr)))
