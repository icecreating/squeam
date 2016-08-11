(load "loadme.scm")

(report (interpret 42))
(report (interpret ''hello))
;(report (interpret '(make _)))
(report (interpret '((make (xs xs)))))
(report (interpret '((make (xs xs)) 1 2 3)))
(report (interpret '(if #f 1 2)))
(report (interpret '(if #t 1 2)))
(report (interpret '((make ((#f) 'no) (_ 'yes)) #f)))
(report (interpret '((make ((#f) 'no) (_ 'yes)) #t)))
(report (interpret '`(hello ,(if #t 'yes 'no))))
(report (interpret '(2 .+ 3)))
(report (interpret '(hide (let x 55))))
(report (interpret '(hide (define (f) 136) (f))))
(report (interpret '(hide
                       (define (factorial n)
                         (match n
                           (0 1)
                           (_ (n .* (factorial (n .- 1))))))
                       (factorial 10))))

(run-load "eg/compact-lambda.scm")

(run-load "eg/sicp1.scm")
(run-load "eg/sicp2.scm")

(run-load "eg/lambdacompiler.scm")
(run-load "eg/parson.scm")
(run-load "eg/parse.scm")
(run-load "eg/intset.scm")
(run-load "eg/circuitoptimizer.scm")
(run-load "eg/fizzbuzz.scm")

(run-load "eg/traceback.scm")
(run-load "eg/failing.scm")

(run-load "eg/hashmap.scm")
(run-load "eg/lambdaterp.scm")
(run-load "eg/fillvector.scm")
(run-load "eg/format.scm")
(run-load "eg/sort.scm")