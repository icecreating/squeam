(define-syntax mcase
  (syntax-rules ()
    ((_ subject clause ...)
     ((mlambda clause ...) subject))))

(define-syntax mlambda
  (syntax-rules ()
    ((_ clause ...)
     (lambda (subject)
       (%match-clauses subject clause ...)))))

(define-syntax %match-clauses
  (syntax-rules ()
    ((_ subject)
     (%match-error subject))
    ((_ subject (pattern) . clauses)
     (let ((match-rest (lambda ()
                         (%match-clauses subject . clauses))))
       (%match subject pattern #t (match-rest))))
    ((_ subject (pattern . body) . clauses)
     (let ((match-rest (lambda ()
                         (%match-clauses subject . clauses))))
       (%match subject pattern (begin . body) (match-rest))))))
    
(define-syntax %match
  (syntax-rules (__ : quote)                    ;N.B. __ was _
    ((_ subject (: __ ok?) then-exp else-exp)
     (if (ok? subject)
         then-exp
         else-exp))
    ((_ subject (: var ok?) then-exp else-exp)
     (if (ok? subject)
         (let ((var subject)) then-exp)
         else-exp))
    ((_ subject (quote datum) then-exp else-exp)
     (if (equal? subject (quote datum)) then-exp else-exp))
    ((_ subject () then-exp else-exp)
     (if (null? subject) then-exp else-exp))
    ((_ subject (h . t) then-exp else-exp)
     (if (pair? subject)
         (mcase (car subject)
                (h (mcase (cdr subject)
                          (t then-exp)
                          (__ else-exp)))
                (__ else-exp))
         else-exp))
    ((_ subject variable then-exp else-exp) ;treating a variable as the only case left
     (let ((variable subject)) then-exp))
    ;; In Gambit we had a case for other constants, like numbers, but
    ;; we're not using it and I don't see how to implement it in
    ;; syntax-rules anyway.
    ))
