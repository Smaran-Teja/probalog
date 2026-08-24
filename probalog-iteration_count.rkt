#lang roulette/example/disrupt
(require "probalog-core.rkt")
(provide run-datalog)

;; ---------------------------------------------------------------------
;; INCORRECT approach — kept here deliberately as a counterexample.
;;
;; This bounds pass 2's round count by however many rounds pass 1 took
;; to reach a fixpoint on the KEY SET (i.e. no new fact identities
;; appear). That is NOT the same question as "how many rounds does
;; every fact's full guard need to fully accumulate all of its
;; derivations." A fact's key can appear via a short derivation route
;; several rounds before an independent, longer route to that SAME
;; fact finishes contributing its own guard — the key-set fixpoint
;; only tracks the former, so this bound can stop pass 2 too early and
;; silently under-count a fact's true probability.
;;
;; See probalog-examples.rkt's "diverging routes" example, where this
;; implementation gives a WRONG answer for Path(N1,N4) while
;; probalog-set-equal.rkt and probalog-bound.rkt agree on the correct one.
;; ---------------------------------------------------------------------

;; Returns (values final-fact-set round-count) — round-count is how many
;; times immediate-plain had to be called before the fact set stopped growing.
(define (saturate-plain/count fact-keys rules)
  (let loop ([full fact-keys] [delta fact-keys] [rounds 0])
    (define-values (next-full next-delta) (immediate-plain full delta rules))
    (if (= (set-count next-full) (set-count full))
        (values full rounds)
        (loop next-full next-delta (add1 rounds)))))

(define (saturate-prob full delta rules bound)
  (define-values (final-full final-delta)
    (for/fold ([full full] [delta delta]) ([_ (in-range bound)])
      (immediate-prob full delta rules)))
  final-full)

(define (run-datalog base-fact-probs rules)
  (define base-set (make-base-set base-fact-probs))
  (define all-keys (make-key-set base-fact-probs))
  (define-values (herbrand-base rounds) (saturate-plain/count all-keys rules))
  (finalize-result (saturate-prob base-set base-set rules rounds)))