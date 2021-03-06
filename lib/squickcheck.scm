;; Random tests from property checks.
;; Based on clickcheck/peckcheck.

;; Glossary:
;;    g    generator context: includes an RNG and a size
;;    gen  generates a value of a type, given a g

(import (use "lib/random") rng<-)
(let default-rng (rng<- 1234567))    ;TODO don't use this all the time

;; TODO report which property failed
;; TODO make and report deterministic seeds
;; TODO catch errors
;; TODO better names
(make all
  (`(,property ,@gens)
   (all .run (context<- default-rng) 40 property gens))
  ({.run g n-times property gens}
   (let failures (flexarray<-))
   (for each! ((_ (range<- n-times)))
     (let inputs (for each ((gen gens))
                   (gen g)))
     (let outcome (call property inputs))
     (match outcome
       (#yes (display "."))
       (_ (display "X")
          (failures .push! `(,outcome ,inputs)))))
   (newline)
   (unless failures.empty?
     (format "Failures for ~w:\n" property)
     (for each! ((`(,outcome ,inputs) failures))
       (format "~w: ~w\n" outcome inputs)))
   failures.empty?))

(to (should be-ok? @arguments)
  (call be-ok? arguments))


;; Generator context

(make context<-
  (`(,rng)
   (context<- rng 20))             ; TODO: is 20 a good default size?
  (`(,rng ,size)
   ;; TODO better method names
   (make gen
     ({.size}        size)
     ({.natural n}   (rng .random-integer n))
     ({.range lo hi} (rng .random-range lo hi))
     ({.a-size}      (rng .random-integer size))
     ({.choose xs}   (rng .pick xs)))))


;; Basic gens
;; TODO maybe name like <claim> etc.

(to (a-claim g)
  (match (g .natural 2)
    (0 #no)
    (1 #yes)))

(to (a-nat g)
  (g .natural g.size))

(to (an-int g)
  (g .range (- g.size) g.size))

(to (a-char g)
  (char<- (g .natural 256)))

(to (a-printable-char g)
  (char<- (g .natural 32 126)))

(to ((a-list-of gen) g)
  (for each ((_ (range<- g.a-size)))
    (gen g)))

(to (a-string g)
  (call string<- ((a-list-of a-char) g)))

(to (a-printable-string g)
  (call string<- ((a-list-of a-printable-char) g)))

(to ((a-tuple @gens) g)
  (for each ((gen gens))
    (gen g)))

(to ((a-choice @gens) g)
  ((g .choose gens) g))


;; Helpers for gens

(to (weighted-choice choices)
  (let total (sum (each '.first choices)))
  (given (g)
    (begin scanning ((i (g .natural total))
                     (`((,weight ,choice) ,@rest) choices))
      (if (< i weight)
          choice
          (scanning (- i weight) rest)))))


(export
  a-claim a-nat an-int a-char a-printable-char a-printable-string a-list-of a-tuple a-choice
  weighted-choice
  all should
  context<-
  )
