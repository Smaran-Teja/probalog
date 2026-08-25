#lang racket/base
(require "lexer.rkt")
(provide parse-probalog)

;; Parses the entire port and returns a list of S-expressions, each
;; one of:
;;   (#%probalog-fact-entry (fact 'Name (list arg ...)) prob)
;;   (#%probalog-rule-entry (rule (fact 'Name (list arg ...))
;;                                 (list (fact 'Name (list arg ...)) ...)))
;;   (#%probalog-query-entry (fact 'Name (list arg ...)))
;; These head symbols are recognized by probalog/expander.rkt's
;; #%module-begin, which consumes and rewrites them — they're never
;; actually bound to real functions/macros.
(define (parse-probalog port)
  (define toks (tokenize port))
  (let loop ([toks toks] [acc '()])
    (if (eq? (token-type (car toks)) 'eof)
        (reverse acc)
        (let-values ([(form rest) (parse-statement toks)])
          (loop rest (cons form acc))))))

;; --- token stream helpers -------------------------------------------

(define (peek toks) (car toks))
(define (peek-type toks) (token-type (car toks)))

(define (expect toks type)
  (unless (eq? (peek-type toks) type)
    (error 'probalog-parser "expected ~a but got ~a (~a)"
           type (peek-type toks) (token-value (peek toks))))
  (values (peek toks) (cdr toks)))

;; --- grammar ----------------------------------------------------------
;; statement := fact-or-rule-decl | query-decl
;; fact-or-rule-decl := NAME '(' arglist ')' ( '::' NUMBER | ':-' body | ε ) '.'
;;   -- omitting '::' NUMBER entirely (i.e. just NAME(args).) declares
;;      a fact with an implicit probability of 1 (a certain fact).
;; query-decl        := '?' NAME '(' arglist ')' '.'
;; body              := clause (',' clause)*
;; clause            := NAME '(' arglist ')'
;; arglist           := arg (',' arg)* | ε
;; arg               := STRING | NUMBER | IDENT

(define (parse-statement toks)
  (if (eq? (peek-type toks) 'question)
      (parse-query (cdr toks))
      (parse-fact-or-rule toks)))

(define (parse-query toks)
  (define-values (name-tok toks1) (expect toks 'ident))
  (check-predicate-name! (token-value name-tok))
  (define-values (args toks2) (parse-parenthesized-arglist toks1))
  (define-values (_ toks3) (expect toks2 'period))
  (values `(#%probalog-query-entry
             (fact ',(string->symbol (token-value name-tok)) (list ,@args)))
          toks3))

(define (parse-fact-or-rule toks)
  (define-values (name-tok toks1) (expect toks 'ident))
  (check-predicate-name! (token-value name-tok))
  (define name-sym (string->symbol (token-value name-tok)))
  (define-values (args toks2) (parse-parenthesized-arglist toks1))
  (cond
    [(eq? (peek-type toks2) 'coloncolon)
     (define-values (_ toks3) (values #f (cdr toks2)))
     (define-values (num-tok toks4) (expect toks3 'number))
     (define-values (__ toks5) (expect toks4 'period))
     (values `(#%probalog-fact-entry
                (fact ',name-sym (list ,@args))
                ,(token-value num-tok))
             toks5)]
    [(eq? (peek-type toks2) 'period)
     ;; No probability annotation at all — defaults to 1 (a certain fact).
     (define-values (_ toks3) (expect toks2 'period))
     (values `(#%probalog-fact-entry
                (fact ',name-sym (list ,@args))
                1)
             toks3)]
    [(eq? (peek-type toks2) 'colon-dash)
     (define-values (_ toks3) (values #f (cdr toks2)))
     (define-values (clauses toks4) (parse-body toks3))
     (define-values (__ toks5) (expect toks4 'period))
     (values `(#%probalog-rule-entry
                (rule (fact ',name-sym (list ,@args))
                      (list ,@clauses)))
             toks5)]
    [else
     (error 'probalog-parser
            "expected '::', ':-', or '.' after ~a(...), got ~a"
            (token-value name-tok) (peek-type toks2))]))

(define (parse-body toks)
  (define-values (c toks1) (parse-clause toks))
  (let loop ([toks toks1] [acc (list c)])
    (if (eq? (peek-type toks) 'comma)
        (let-values ([(c2 toks2) (parse-clause (cdr toks))])
          (loop toks2 (cons c2 acc)))
        (values (reverse acc) toks))))

(define (parse-clause toks)
  (define-values (name-tok toks1) (expect toks 'ident))
  (check-predicate-name! (token-value name-tok))
  (define-values (args toks2) (parse-parenthesized-arglist toks1))
  (values `(fact ',(string->symbol (token-value name-tok)) (list ,@args)) toks2))

(define (parse-parenthesized-arglist toks)
  (define-values (_ toks1) (expect toks 'lparen))
  (if (eq? (peek-type toks1) 'rparen)
      (values '() (cdr toks1))
      (let loop ([toks toks1] [acc '()])
        (define-values (a toks2) (parse-arg toks))
        (if (eq? (peek-type toks2) 'comma)
            (loop (cdr toks2) (cons a acc))
            (let-values ([(_ toks3) (expect toks2 'rparen)])
              (values (reverse (cons a acc)) toks3))))))

(define (parse-arg toks)
  (case (peek-type toks)
    [(string) (values (token-value (peek toks)) (cdr toks))]
    [(number) (values (token-value (peek toks)) (cdr toks))]
    [(ident)
     (define name (token-value (peek toks)))
     (values `(quote ,(string->symbol name)) (cdr toks))]
    [else (error 'probalog-parser "expected an argument, got ~a" (peek-type toks))]))

;; Predicate names must start with an uppercase letter, matching the
;; convention used throughout — variables (lowercase-starting
;; identifiers) are only valid in argument position, never as the
;; head of a fact/rule/clause/query.
(define (check-predicate-name! s)
  (unless (and (> (string-length s) 0) (char-upper-case? (string-ref s 0)))
    (error 'probalog-parser
           "predicate names must start with an uppercase letter: ~a" s)))
