;; Solve mostly-linear systems of equations, a la Van Wyk's IDEAL.

;; Constraints are equations between expressions. We represent one as
;; an expression, with '=0' implicit. We try to reduce each expression
;; to a linear combination of variables plus a constant, then
;; eliminate one of the variables, and continue. Nonlinear expressions
;; get put off to try again later.

(import (use "lib/queue")
  empty empty?
  push extend
  peek)

(let ratio-m (use "lib/ratio"))
(import ratio-m ratio<-)

(let `(,r+ ,r- ,r* ,r/) (each ratio-m '(+ - * /)))
(let r-cmp (ratio-m 'compare))

(let zero    (ratio<- 0))
(let one     (ratio<- 1))
(let neg-one (ratio<- -1))

(to (e= defaulty? e1 e2)
  {equation defaulty? (e- e1 e2)})

;; Try to determine as many variables as we can by elimination.
;; Return 'inconsistent if we noticed a contradiction, 'done if we
;; discharged all of the constraints, or else 'stuck. Done does not
;; imply that we determined all of the variables, note. If
;; inconsistent, we still try to determine what we can of the rest.
(to (solve equations)
  (begin solving ((inconsistent? #no) ; Noticed a contradiction yet?
                  (progress? #no)     ; Any progress since the last assessment?
                  (agenda (push (extend empty equations) 'assessment)))
    (match (peek agenda)
      ({nonempty task pending}
       (match task
         ('assessment
          (if progress?
              (solving inconsistent? #no (push pending 'assessment))
              (case (inconsistent?    'inconsistent)
                    ((empty? pending) 'done)
                    (else             'stuck))))
         ({equation defaulty? expr}
          (match (eval-expr expr)       ;XXX better name?
            ('nonlinear                 ;TODO call it #no instead?
             (solving inconsistent? progress? (push pending task)))
            (combo
             (let terms (expand combo))
             (case ((varies? terms)
                    (eliminate-a-variable terms)
                    (solving inconsistent? #yes pending))
                   ((or defaulty? (zeroish? (constant terms)))
                    ;; The equation was either only a default (whose
                    ;; inconsistency is allowed) or it reduced to an
                    ;; uninformative 0=0: drop it.
                    (solving inconsistent? #yes pending))
                   (else
                    (format "Inconsistent: ~w\n" combo)
                    (solving #yes progress? pending)))))))))))

(to (e+ e1 e2) {combine e1 one e2})
(to (e- e1 e2) {combine e1 neg-one e2})
(to (e* e1 e2) {* e1 e2})
(to (e/ e1 e2) {/ e1 e2})

(to (get-value e ejector)
  (match (eval-expr e)
    ('nonlinear (ejector .eject {not-fixed e}))
    (combo
     (let terms (expand combo))
     (when (varies? terms)
       (ejector .eject {not-fixed e}))
     (get-constant terms))))

(to (eval-expr e)
  (match e
    ({combo _}
     e)
    ({combine arg1 coeff arg2}
     (combine (eval-expr arg1) coeff (eval-expr arg2)))
    ({* arg1 arg2}
     (let combo1 (eval-expr arg1))   (let terms1 (expand combo1))
     (let combo2 (eval-expr arg2))   (let terms2 (expand combo2))
     (case ((and (varies? terms1) (varies? terms2))
            'nonlinear)
           ((varies? terms1) (scale combo1 (get-constant terms2)))
           (else             (scale combo2 (get-constant terms1)))))
    ({/ arg1 arg2}
     (let combo1 (eval-expr arg1))
     (let combo2 (eval-expr arg2))
     (let terms2 (expand combo2))
     (if (varies? terms2)
         'nonlinear
         (scale combo1 (r/ one (get-constant terms2))))) ;TODO reciprocal function
    ({nonlinear fn arg}
     (let combo (eval-expr arg))
     (let terms (expand combo))
     (if (varies? terms)
         'nonlinear
         (do (let value (get-constant terms))
             (surely (ratio? value))
             (constant<- (fn value)))))
    ))

(to (constant<- value)
  (combo<- (map<- `((,const-term ,value))))) ;TODO use sorted lists instead?

(to (variable<- name)
  (combo<- (map<- `((,name ,one)))))

(to (combo<- terms)
  terms)                               ;since we're using exact ratios

(to (varies? terms)
  (not (terms .maps? const-term)))

(to (get-constant terms)
  (surely (not (varies? terms)))
  (terms .get const-term zero))

;; TODO more
