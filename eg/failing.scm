;; An example failing computation, to exercise the debugger.
;; This turned into essentially a repeat of test-continuations.scm.

(import (use "lib/traceback") on-error-traceback)

(define (factorial n)
  (if (= 0 n)
      (error "I don't know 0!")
      (* n (factorial (- n 1)))))

(define (on-error-complain-and-continue k @evil) ;TODO 'k' is too abbreviated
  (call on-error-traceback `(,k ,@evil))
  (display "About to continue with 10") (newline)
  (the-signal-handler-box .^= on-error-traceback) ;; Restore the usual handler.
  (k .answer 10))

(the-signal-handler-box .^= on-error-complain-and-continue)
(print (factorial 5))
