#lang roulette/example/disrupt
(require "probalog-core.rkt")
(provide run-datalog)

;; Loop immediate-prob (semi-naive: full db + last round's delta) until
;; set-equal? (solver-backed logical equivalence of guards, not just
;; key membership) reports no change to the full db.
(define (saturate-prob full delta rules)
  (define-values (next-full next-delta) (immediate-prob full delta rules))
  (if (set-equal? next-full full)
      full
      (saturate-prob next-full next-delta rules)))

(define (run-datalog base-fact-probs rules)
  (define base-set (make-base-set base-fact-probs))
  (finalize-result (saturate-prob base-set base-set rules)))