(import (use "lib/squickcheck")
  a-claim a-nat an-int a-char a-printable-char a-printable-string a-list-of a-tuple a-choice
  weighted-choice
  all should  ;; I dunno what to call it yet
  )

(for all ((a an-int) (b an-int))
  ;; Ints are commutative.
  (should = (+ a b) (+ b a)))

;; A deliberately failing property:

(for all ((L (a-list-of a-nat)))
  ;; Lists are palindromic (not!)
  (should = L (reverse L)))
