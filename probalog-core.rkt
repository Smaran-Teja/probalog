#lang roulette/example/disrupt
(require "hash-set.rkt")
(provide (all-defined-out)
         (all-from-out "hash-set.rkt"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program representation

;; name is the predicate identifier, and
;; args is a list of any (concrete) arguments supplied to the fact.

;; args can be symbols, which represent variables 
(struct fact (name args)
  #:transparent
  #:methods gen:custom-write
  [(define (write-proc self port mode)
     (write-string (symbol->string (fact-name self)) port)
     (write-string "(" port)
     (for ([a (fact-args self)] [i (in-naturals)])
       (when (> i 0) (write-string ", " port))
       (if (string? a)
           (write-string (format "~s" a) port)
           (write a port)))
     (write-string ")" port))])

;; head is the derived fact, and body is a list of
;; facts (clauses) that must be satisfied. 
(struct rule (head body) #:transparent)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Matching

;; Match a fact pattern against f, given existing bindings. Returns
;; extended bindings, or #f if the match fails.
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Probabilistic fact database

;; base-fact-probs : list of (cons fact probability)
(define (make-base-set base-fact-probs)
  (for/sym-set ([fp base-fact-probs])
    (values (car fp) (flip (cdr fp)))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Immediate consequence operator (semi-naive)

;; predicate name -> list of (fact . guard) pairs
(define (index-by-name st)
  (for/fold ([idx (hash)]) ([(k g) st])
    (hash-update idx (fact-name k) (lambda (l) (cons (cons k g) l)) '())))

;; Matches body left to right; the clause at delta-pos draws from
;; delta-idx, every other clause draws from full-idx.
;; Produces a list of (bindings . guard) pairs, or "world"s 
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


;; `delta` is what was freshly derived in the most recent iteration.
;; Only derivations using delta in at least one clause position are
;; computed, since anything using only older facts was already found.

;; try every clause position as the required-delta position.
;; produces a list of worlds (bindings . guard) pairs
(define (find-bindings-prob/delta body full delta)
  (define full-idx (index-by-name full))
  (define delta-idx (index-by-name delta))
  (define n (length body))
  (for*/list ([delta-pos (in-range n)]
              [w (find-bindings-prob/at body full-idx delta-idx delta-pos)])
    w))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Timing instrumentation

(define total-find-bindings-time 0.0)
(define total-guard-build-time 0.0)
(define total-set-union-time 0.0)

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
              (for/sym-set ([w bindings])
                (values (substitute (rule-head r) (car w)) (cdr w))))))

;; Returns (values new-full new-delta): new-delta is exactly what's
;; fresh this round, new-full is full ∪ new-delta.
(define (immediate-prob full delta rules)
  (for/fold ([full-acc full] [new-acc (set)])
            ([r rules])
    (define delta-pool (time-it! add-set-union-time! (lambda () (set-union delta new-acc))))
    (define fresh (rule-apply-prob/delta r full-acc delta-pool))
    (define new-full-acc (time-it! add-set-union-time! (lambda () (set-union full-acc fresh))))
    (define new-new-acc (time-it! add-set-union-time! (lambda () (set-union new-acc fresh))))
    (values new-full-acc new-new-acc)))

;; re-exporting query from roulette/example/disrupt as query-fact 
(define (query-fact result f)
  (query (set-member? result f)))