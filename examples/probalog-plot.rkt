#lang racket
(require plot
         "probalog-examples.rkt")

;; Calling `plot` inside a `for` loop (rather than as a bare top-level
;; expression) means its return value is discarded, so DrRacket's
;; auto-display-top-level-results behavior never kicks in — nothing
;; would show up otherwise. Setting this makes every `plot` call open
;; its own window immediately instead of relying on that.
(plot-new-window? #t)

;; sanity-results and full-results are plain lists of
;; (layers width wall-elapsed equal-time bindings-time guard-time union-time)
;; 7-tuples, provided by probalog-examples.rkt (a #lang roulette
;; module) — by the time they cross the module boundary here, they're
;; just ordinary Racket lists/numbers, so plotting them in a plain
;; #lang racket module works without any interaction with roulette's
;; language extensions.

;; One line per `layers` value, x-axis = width, y-axis = whatever
;; `extract` pulls out of each result tuple.
(define (plot-sweep results layers-values extract y-label title
                     #:y-min [y-min #f] #:y-max [y-max #f])
  (define (series-for layers)
    (for/list ([r results] #:when (= (car r) layers))
      (vector (cadr r) (extract r))))
  (define renderers
    (for/list ([layers layers-values])
      (lines (series-for layers) #:label (format "layers=~a" layers))))
  (plot renderers
        #:x-label "width"
        #:y-label y-label
        #:y-min y-min #:y-max y-max
        #:title title
        #:legend-anchor 'outside-right-top))

;; Field accessors for the 7-tuple: (layers width wall equal bindings guard union)
(define (get-wall r) (caddr r))
(define (get-equal r) (cadddr r))
(define (get-bindings r) (list-ref r 4))
(define (get-guard r) (list-ref r 5))

(define full-layers-values (for/list ([l (in-range 1 31 2)]) l))

;; Re-run this from the Interactions window (after the file has loaded
;; once) to redisplay all plots without re-running the sweep. Only the
;; categories that showed non-trivial time in practice are plotted —
;; set-union and the unaccounted-for residual were negligible, as
;; were all the ratio-of-total plots, so they're dropped here.
(define (show-plots)
  (for ([spec (list (cons get-wall "total wall-clock time (ms)")
                     (cons get-bindings "time in find-bindings-prob/delta (ms)")
                     (cons get-guard "time in set-add (ms)")
                     (cons get-equal "time in my-hash-equal? (ms)"))])
    (plot-sweep full-results full-layers-values (car spec) (cdr spec)
                (format "~a vs. layers/width" (cdr spec)))))

(show-plots)