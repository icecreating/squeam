;; Run a whole lot of examples, none of which should take long.

(print 42)
(print 'hello)
; (print (make _))
(print ((make (xs xs))))
(print ((make (xs xs)) 1 2 3))
(print (if #no 1 2))
(print (if #yes 1 2))
(print ((make ((#no) 'no) (_ 'yes)) #no))
(print ((make ((#no) 'no) (_ 'yes)) #yes))
(print `(hello ,(if #yes 'yes 'no)))
(print (2 .+ 3))
(print (hide (let x 55)))
(print (hide (define (f) 136) (f)))
(print (hide
        (define (factorial n)
          (match n
            (0 1)
            (_ (n .* (factorial (n .- 1))))))
        (factorial 10)))

(define (loud-load filename)
  (newline)
  (display "-------- ")
  (display filename)
  (display " --------")
  (newline)
  (use filename))

(loud-load "lib/memoize")
(loud-load "lib/parson")
(loud-load "lib/regex")
(loud-load "lib/parse")
(loud-load "lib/unify")

(loud-load "eg/test-export-import")
(loud-load "eg/test-quasiquote")
(loud-load "eg/test-strings")
(loud-load "eg/test-continuations")
(loud-load "eg/test-pattern-matching")
(loud-load "eg/test-use")

(loud-load "eg/test-hashmap")
(loud-load "eg/test-format")
(loud-load "eg/test-fillvector")
(loud-load "eg/test-sort")
(loud-load "eg/test-hashset")
(loud-load "eg/test-memoize")
(loud-load "eg/test-regex")
(loud-load "eg/test-parson")
(loud-load "eg/test-parse")
(loud-load "eg/test-unify")
(loud-load "eg/test-complex")
(loud-load "eg/test-dd")
(loud-load "eg/test-ratio")

(loud-load "eg/compact-lambda")
(loud-load "eg/sicp1")
(loud-load "eg/sicp2")
(loud-load "eg/lambdacompiler")
(loud-load "eg/intset1")
(loud-load "eg/intset2")
(loud-load "eg/circuitoptimizer")
(loud-load "eg/fizzbuzz")
(loud-load "eg/failing")
(loud-load "eg/lambdaterp")
(loud-load "eg/tictactoe")
(loud-load "eg/max-path-sum")
(loud-load "eg/test-metaterp")
