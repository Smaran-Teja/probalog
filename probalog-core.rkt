#lang roulette/example/disrupt
(require "hash-set.rkt")
(provide (all-defined-out)
         (all-from-out "hash-set.rkt"))

;; A concrete placeholder that's never a real fact — used as the "else"
;; branch when inserting a fact under a symbolic guard.
(struct not-a-fact ())
(define sentinel (not-a-fact))

;; args is a list of any type of argument value
(struct fact (name args) #:transparent)
;; head is a fact, and body is a list of facts
(struct rule (head body) #:transparent)

;; ---------------------------------------------------------------------
;; Unification (bindings are non-symbolic plain racket hashes)
;; ---------------------------------------------------------------------

; Match a fact pattern to some provided fact f with existing bindings
; Return #f if match fails, else return bindings
(define (match-fact pattern f bindings)
  (and (equal? (fact-name pattern) (fact-name f))
       (= (length (fact-args pattern)) (length (fact-args f)))
       (match-args (fact-args pattern) (fact-args f) bindings)))

(define (match-args pattern-args fact-args bindings)
  (cond
    [(null? pattern-args) bindings]
    [else
     (define p (car pattern-args))
     (define a (car fact-args))
     (cond
       [(symbol? p)
        (cond
          [(hash-has-key? bindings p)
           (and (equal? (hash-ref bindings p) a)
                (match-args (cdr pattern-args) (cdr fact-args) bindings))]
          [else
           (match-args (cdr pattern-args) (cdr fact-args)
                       (hash-set bindings p a))])]
       [else
        (and (equal? p a)
             (match-args (cdr pattern-args) (cdr fact-args) bindings))])]))

(define (substitute head bindings)
  (fact (fact-name head)
        (map (lambda (a) (if (symbol? a) (hash-ref bindings a) a))
             (fact-args head))))

;; ---------------------------------------------------------------------
;; sym-set helpers for a probabilistic fact database
;; ---------------------------------------------------------------------

;; Add fact f to sym-set st, present under guard g (possibly symbolic).
;; Reuses the existing hash-set.rkt merge machinery for free: my-hash-set
;; decomposes the (if g f sentinel) union into per-key guarded entries,
;; and set-union later ORs guards across multiple derivations.
(define (set-add-guarded st f g)
  (set-add st (if g f sentinel)))

;; Pull out just the real facts (drop the sentinel) as a list of
;; (fact . guard) pairs, for use when iterating the set during matching.
(define (set-fact-guards st)
  (for/list ([(k g) st] #:when (fact? k))
    (cons k g)))

;; base-fact-probs : list of (cons fact probability)
(define (make-base-set base-fact-probs)
  (for/fold ([st (set)]) ([fp base-fact-probs])
    (set-add-guarded st (car fp) (flip (cdr fp)))))

;; Build a plain (guard-free) sym-set of just the base fact identities —
;; used by pass-1 saturation in the bound-based implementations.
(define (make-key-set base-fact-probs)
  (for/fold ([st (set)]) ([fp base-fact-probs])
    (set-add st (car fp))))

;; ---------------------------------------------------------------------
;; Probabilistic guard propagation — the immediate-consequence operator
;; shared by ALL fixpoint strategies. Only the outer loop that decides
;; when to STOP calling this differs between implementations.
;;
;; SEMI-NAIVE EVALUATION: naive evaluation re-joins the ENTIRE database
;; against every rule body every round, including facts that were
;; already fully processed in earlier rounds — any derivation using
;; only "old" facts in every clause position was necessarily already
;; found in some earlier round, so redoing that join is wasted work.
;; Semi-naive evaluation instead tracks a `delta` (facts newly derived
;; last round) and only computes derivations that use delta in AT
;; LEAST ONE clause position (trying each position in turn). Anything
;; missed by this restriction was already found previously.
;;
;; This is purely a performance change: since guards are merged via OR
;; (set-union / set-add-guarded), and OR is idempotent, re-deriving an
;; already-known fact with the same guard is always harmless even if
;; the delta-restriction is imperfect — it just avoids most of the
;; redundant work rather than being required for correctness.
;;
;; Rules still see derivations from earlier rules in the same round
;; (threaded via for/fold, matching the non-semi-naive version's
;; behavior), and freshly-derived facts from earlier rules in this
;; same round are folded into the delta pool for later rules too.
;; ---------------------------------------------------------------------

;; Build a hash: predicate name -> list of (fact . guard) pairs, so a
;; clause only needs to scan facts of its own predicate rather than
;; every fact in the database. Facts of different predicates can never
;; unify anyway (match-fact's first check is (equal? (fact-name ...))),
;; so this purely prunes wasted match-fact calls, no behavior change.
(define (index-by-name fgs)
  (for/fold ([idx (hash)]) ([fg fgs])
    (hash-update idx (fact-name (car fg)) (lambda (l) (cons fg l)) '())))

;; Match body left to right, where the clause at index delta-pos draws
;; candidates from delta-idx, and every other clause draws from full-idx.
(define (find-bindings-prob/at body full-idx delta-idx delta-pos)
  (for/fold ([worlds (list (cons (hash) #t))])
            ([clause body] [i (in-naturals)])
    (define idx (if (= i delta-pos) delta-idx full-idx))
    (define candidates (hash-ref idx (fact-name clause) '()))
    (for*/list ([w worlds]
                [fg candidates]
                [b (in-value (match-fact clause (car fg) (car w)))]
                #:when b)
      (cons b (and (cdr w) (cdr fg))))))

;; All derivations of body that use delta in at least one clause
;; position (tries every position as the required-delta position).
(define (find-bindings-prob/delta body full delta)
  (define full-idx (index-by-name (set-fact-guards full)))
  (define delta-idx (index-by-name (set-fact-guards delta)))
  (define n (length body))
  (for*/list ([delta-pos (in-range n)]
              [w (find-bindings-prob/at body full-idx delta-idx delta-pos)])
    w))

;; ---------------------------------------------------------------------
;; Timing instrumentation, to see where time goes once my-hash-equal?'s
;; share of total time shrinks. Each accumulator sums milliseconds
;; spent in one specific piece of work, across the whole run. Only
;; this module mutates these (Racket disallows set! on a variable
;; imported from another module), so read them from elsewhere via
;; plain reference — same pattern as hash-set.rkt's
;; total-my-hash-equal?-time.
;; ---------------------------------------------------------------------
(define total-find-bindings-time 0.0)  ; unification/join work
(define total-guard-build-time 0.0)    ; set-add-guarded (guard construction)
(define total-set-union-time 0.0)      ; merging full/delta accumulators

;; Runs thunk, adds its wall-clock time (ms) to the accumulator that
;; `updater!` mutates, and returns thunk's result unchanged.
(define (time-it! updater! thunk)
  (define start (current-inexact-monotonic-milliseconds))
  (define result (thunk))
  (updater! (- (current-inexact-monotonic-milliseconds) start))
  result)

(define (add-find-bindings-time! dt) (set! total-find-bindings-time (+ total-find-bindings-time dt)))
(define (add-guard-build-time! dt) (set! total-guard-build-time (+ total-guard-build-time dt)))
(define (add-set-union-time! dt) (set! total-set-union-time (+ total-set-union-time dt)))

(define (rule-apply-prob/delta r full delta)
  (define bindings (time-it! add-find-bindings-time!
                              (lambda () (find-bindings-prob/delta (rule-body r) full delta))))
  (time-it! add-guard-build-time!
            (lambda ()
              (for/fold ([acc (set)]) ([w bindings])
                (set-add-guarded acc (substitute (rule-head r) (car w)) (cdr w))))))

;; Runs one semi-naive round: `full` is everything known so far,
;; `delta` is what was freshly derived last round. Returns (values
;; new-full new-delta), where new-delta is exactly what's fresh from
;; THIS round (to seed the next round), and new-full is full ∪ new-delta.
(define (immediate-prob full delta rules)
  (for/fold ([full-acc full] [new-acc (set)])
            ([r rules])
    (define delta-pool (time-it! add-set-union-time! (lambda () (set-union delta new-acc))))
    (define fresh (rule-apply-prob/delta r full-acc delta-pool))
    (define new-full-acc (time-it! add-set-union-time! (lambda () (set-union full-acc fresh))))
    (define new-new-acc (time-it! add-set-union-time! (lambda () (set-union new-acc fresh))))
    (values new-full-acc new-new-acc)))

;; Strip the sentinel placeholder out of a finished result set.
(define (finalize-result st)
  (set-remove st sentinel))

;; ---------------------------------------------------------------------
;; Plain (guard-free) immediate-consequence operator — shared by the
;; bound-based implementations' pass 1, which finds the Herbrand base
;; (and, in the flawed variant, is also mined for a round count).
;; fact-keys is a sym-set with every guard forced to #t. Semi-naive,
;; same structure/reasoning as immediate-prob above but without guards.
;; ---------------------------------------------------------------------

;; Same idea as index-by-name, but for a plain list of facts (no guards).
(define (index-facts-by-name fs)
  (for/fold ([idx (hash)]) ([f fs])
    (hash-update idx (fact-name f) (lambda (l) (cons f l)) '())))

(define (find-bindings-plain/at body full-idx delta-idx delta-pos)
  (for/fold ([bindings-set (list (hash))])
            ([clause body] [i (in-naturals)])
    (define idx (if (= i delta-pos) delta-idx full-idx))
    (define candidates (hash-ref idx (fact-name clause) '()))
    (for*/list ([b bindings-set]
                [f candidates]
                [m (in-value (match-fact clause f b))]
                #:when m)
      m)))

(define (find-bindings-plain/delta body full delta)
  (define full-idx (index-facts-by-name (map car (set-fact-guards full))))
  (define delta-idx (index-facts-by-name (map car (set-fact-guards delta))))
  (define n (length body))
  (for*/list ([delta-pos (in-range n)]
              [b (find-bindings-plain/at body full-idx delta-idx delta-pos)])
    b))

(define (derive-plain/delta r full delta)
  (for/list ([b (find-bindings-plain/delta (rule-body r) full delta)])
    (substitute (rule-head r) b)))

;; Runs one semi-naive round over plain (guard-free) fact identities.
;; Returns (values new-full new-delta), same contract as immediate-prob.
(define (immediate-plain full delta rules)
  (for/fold ([full-acc full] [new-acc (set)])
            ([r rules])
    (define delta-pool (set-union delta new-acc))
    (define fresh-facts (derive-plain/delta r full-acc delta-pool))
    (define-values (full-acc2 new-acc2)
      (for/fold ([fa full-acc] [na new-acc]) ([f fresh-facts])
        (values (set-add fa f) (set-add na f))))
    (values full-acc2 new-acc2)))