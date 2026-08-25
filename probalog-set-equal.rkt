#lang roulette/example/disrupt
(require "probalog-core.rkt")
(provide run-datalog)

;; Loop immediate-prob (semi-naive: full db + last round's delta) until
;; the guards stop changing. Rather than comparing every key in the
;; database (set-equal?), we only need to check keys that this round's
;; delta actually touched — any key immediate-prob didn't union new
;; content into is guaranteed to be identical in next-full and full
;; already, so checking it would just be a solver call with a foregone
;; conclusion. This cuts the number of Z3 calls per round roughly in
;; proportion to how small the delta is relative to the whole database.
(define (saturate-prob full delta rules)
  (define-values (next-full next-delta) (immediate-prob full delta rules))
  (define changed-keys (for/list ([(k g) next-delta]) k))
  (if (set-equal? next-full full changed-keys)
      full
      (saturate-prob next-full next-delta rules)))

(define (run-datalog base-fact-probs rules)
  (define base-set (make-base-set base-fact-probs))
  (saturate-prob base-set base-set rules))