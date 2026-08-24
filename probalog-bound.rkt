#lang roulette/example/disrupt
(require "probalog-core.rkt")
(provide run-datalog)

;; ---------------------------------------------------------------------
;; Pass 1: plain (guard-free) saturation (immediate-plain is shared,
;; from probalog-core.rkt), to find the Herbrand base. The bound handed
;; to pass 2 is (set-count herbrand-base) + 1 — this bounds the longest
;; possible SIMPLE derivation chain: a chain longer than the total
;; number of distinct facts would have to reuse a fact, by pigeonhole,
;; making it non-minimal/redundant. This bound holds regardless of
;; rule ordering or batching strategy, unlike reusing this pass's own
;; round count (see probalog-iteration_count.rkt for why that's unsound).
;; ---------------------------------------------------------------------

(define (saturate-plain fact-keys rules)
  (let loop ([full fact-keys] [delta fact-keys])
    (define-values (next-full next-delta) (immediate-plain full delta rules))
    (if (= (set-count next-full) (set-count full))
        full
        (loop next-full next-delta))))

;; ---------------------------------------------------------------------
;; Pass 2: run immediate-prob (shared, semi-naive, from probalog-core.rkt)
;; a fixed, generously-bounded number of rounds.
;; ---------------------------------------------------------------------

(define (saturate-prob full delta rules bound)
  (define-values (final-full final-delta)
    (for/fold ([full full] [delta delta]) ([_ (in-range bound)])
      (immediate-prob full delta rules)))
  final-full)

(define (run-datalog base-fact-probs rules)
  (define base-set (make-base-set base-fact-probs))
  (define all-keys (make-key-set base-fact-probs))
  (define herbrand-base (saturate-plain all-keys rules))
  (define bound (+ 1 (set-count herbrand-base)))
  (finalize-result (saturate-prob base-set base-set rules bound)))