;; Rational numbers
;; same TODOs as complex numbers
;; n = numerator
;; d = denominator

;; N.B. all functions assume the {ratio n d} structures come in 
;; reduced to lowest terms (and with positive denom), and preserve
;; the same invariant.

(to (ratio? thing)
  (match thing
    ({ratio n d}
     (and (integer? n) (integer? d) (not= d 0)))
    (_ #no)))

(make ratio<-
  (`(,n)
   (surely (integer? n))
   {ratio n 1})
  (`(,n ,d)
   (surely (integer? n))
   (surely (integer? d))
   (reduce n d)))
    
(to (reduce n d)
  (case ((= d 0) (error "Divide by 0"))
        ((< d 0) (lowest-terms (- n) (- d)))
        (else    (lowest-terms n d))))

(to (lowest-terms n d)
  (let g (gcd n d))
  ;; TODO when we can mix number types: return an int if d/g = 1.
  {ratio (n .quotient g)
         (d .quotient g)})

(to (r* {ratio n1 d1} {ratio n2 d2})
  (lowest-terms (* n1 n2)
                (* d1 d2)))

(to (r/ {ratio n1 d1} {ratio n2 d2})
  (reduce (* n1 d2)
          (* d1 n2)))

(to (r+ {ratio n1 d1} {ratio n2 d2})
  (lowest-terms (+ (* n1 d2) (* n2 d1))
                (* d1 d2)))

(to (r- {ratio n1 d1} {ratio n2 d2})
  (lowest-terms (- (* n1 d2) (* n2 d1))
                (* d1 d2)))

(to (compare {ratio n1 d1} {ratio n2 d2})
  ((* n1 d2) .compare (* n2 d1)))

(to (as-float {ratio n d})
  (/ (exact->inexact n) d))

(map<- `(
         (ratio? ,ratio?)
         (ratio<- ,ratio<-)
         (+ ,r+)
         (- ,r-)
         (* ,r*)
         (/ ,r/)
         (compare ,compare)
         (as-float ,as-float)
         ))
