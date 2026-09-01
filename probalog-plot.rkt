#lang racket
(require plot
         "probalog-examples.rkt")

;; Calling `plot` inside a function (rather than as a bare top-level
;; expression) means its return value is discarded, so DrRacket's
;; auto-display-top-level-results behavior never kicks in. Setting
;; this makes every `plot` call open its own window instead.
(plot-new-window? #t)

;; benchmark-results is a plain list of
;; (name wall equal bindings guard union index) entries, provided by
;; probalog-examples.rkt (a #lang roulette module) -- by the time they
;; cross the module boundary here they're ordinary Racket
;; lists/numbers, so plotting them in a plain #lang racket module
;; works without any interaction with roulette's language extensions.

;; Timing breakdown as a single stacked horizontal bar.
;; stacked-histogram takes (vector label (list value ...)) pairs, one
;; segment per value; with a single category that's one bar split into
;; colored segments. #:invert? #t lays it out horizontally.
(define (plot-breakdown parts title)
  (define total (apply + (map cdr parts)))
  (plot (stacked-histogram
         (list (vector "" (map cdr parts)))
         #:invert? #t
         #:labels (for/list ([p parts])
                    (format "~a (~a%)"
                            (car p)
                            (~r (* 100 (/ (cdr p) total)) #:precision 1))))
        #:title title
        #:x-label "time (ms)"
        #:y-label #f
        #:legend-anchor 'outside-right-top))

;; Timing split aggregated across every benchmark. "other" is total
;; wall-clock minus everything accounted for (GC, misc bookkeeping).
(define (show-timing-split [results benchmark-results])
  (define-values (wall equal bindings guard union index)
    (aggregate-timing results))
  (define named
    (list (cons "find-bindings" bindings)
          (cons "set-add" guard)
          (cons "my-hash-equal?" equal)
          (cons "index construction" index)
          (cons "set-union" union)))
  (define parts
    (append named
            (list (cons "other" (max 0 (- wall (apply + (map cdr named))))))))
  (plot-breakdown (sort parts > #:key cdr)
                  (format "timing split across ~a benchmarks (~ams total)"
                          (length results) (~r wall #:precision 0))))

(show-timing-split)