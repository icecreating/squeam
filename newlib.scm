;; stdlib

(define (foldl f z xs)
  (if xs.empty?
      z
      (foldl f (f z xs.first) xs.rest)))

(define (foldr f xs z)
  (if xs.empty?
      z
      (f xs.first (foldr f xs.rest z))))

(define (foldr1 f xs)
  (let tail xs.rest)
  (if tail.empty?
      xs.first
      (f xs.first (foldr1 f tail))))

(define (each f xs)
  (for foldr ((x xs) (ys '()))
    (cons (f x) ys)))

(define (gather f xs)
  (for foldr ((x xs) (ys '()))
    (chain (f x) ys)))

(define (filter ok? xs)
  (for foldr ((x xs) (ys '()))
    (if (ok? x) (cons x ys) ys)))

(define (union set1 set2)
  (for foldr ((x set1) (ys set2))
    (if (set2 .maps-to? x) ys (cons x ys))))

(define (remove set x)
  ;; XXX removes *all* instances -- but we know a set has at most 1
  (for filter ((element set))
    (not (= x element))))

(define (list<- @arguments)
  arguments)

(make chain
  (() '())
  ((xs) xs)
  ((xs ys) (xs .chain ys))
  ((@arguments) (foldr1 '.chain arguments)))

(define (some ok? xs)
  (and (not xs.empty?)
       (or (ok? xs.first)
           (some ok? xs.rest))))

(define (every ok? xs)
  (or xs.empty?
      (and (ok? xs.first)
           (every ok? xs.rest))))

(define (print x)
  (write x)
  (newline))

(define (each! f xs)
  (unless xs.empty?
    (f xs.first)
    (each! f xs.rest)))

(define ((compose f g) @arguments)
  (f (call g arguments)))
