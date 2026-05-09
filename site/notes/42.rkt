#lang racket

(define (read-string s)
  (with-handlers
      ([(λ (_) #t) (λ (_) 0)])
    (define in (open-input-string s))
    (let loop ()
      (unless (eof-object? (read in))
        (loop)))
    1))

(define (number->chars n)
  (string->list (~a n
                    #:min-width 6
                    #:pad-string "0")))

(define (char->string c)
  (match c
    [#\0 "((((((("]
    [#\1 "(((((("]
    [#\2 "((((("]
    [#\3 "(((("]
    [#\4 "((("]
    [#\5 "(("]
    [#\6 "("]
    [#\8 ")"]
    [#\9 "))"]
    [_ "horses"]))

(define (number->string n)
  (define char-list
    (map char->string (number->chars n)))

  (list->string
   (sort (append* (map string->list char-list))
         char<?)))

(for/sum ([n (in-range 1000000)])
  (read-string (number->string n)))
