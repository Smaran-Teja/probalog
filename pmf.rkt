#lang racket/base

;; Probability mass functions: what a query returns.
;;
;; This mirrors the pmf in roulette's disrupt rather than reusing it, so
;; that probalog carries no dependency on roulette's Racket code. The two
;; are separate types; nothing crosses that boundary.

(provide pmf pmf? pmf-hash pmf-support in-pmf for/pmf)

(require racket/match
         racket/struct)

;; A pmf is callable: applying it to a value gives that value's
;; probability, and 0 for anything outside the support.
(struct pmf (hash)
  #:property prop:procedure
  (λ (self value) (hash-ref (pmf-hash self) value 0))
  #:methods gen:custom-write
  [(define write-proc
     (make-constructor-style-printer
      (λ (self) 'pmf)
      (λ (self)
        (match-define (pmf ht) self)
        (for/list ([(k v) (in-hash ht)])
          (unquoted-printing-string (format "[~v ~a]" k v))))))])

(define (pmf-support p) (hash-keys (pmf-hash p)))

(define (in-pmf p) (in-hash (pmf-hash p)))

(define-syntax-rule (for/pmf (for-clause ...) body-or-break ... body)
  (pmf (for/hash (for-clause ...) body-or-break ... body)))
