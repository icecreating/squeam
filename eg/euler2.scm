;; https://projecteuler.net/problem=2
;; The sum of the even-valued terms of the Fibonacci sequence whose
;; values do not exceed four million.

(to (euler2 n)
  (sum (those even? (fibs n))))

(to (even? n)
  (= 0 (n .remainder 2)))

(to (fibs n)
  (begin fibbing ((a 1) (b 1))
    (if (<= a n)
        (cons a (fibbing b (+ a b)))
        '())))

;(print (euler2 10))
(print (euler2 4000000))
