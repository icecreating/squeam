;; This special source file must be written to load without actually
;; invoking any primitive object, because this code *defines* their
;; scripts. Only after this file is loaded will the definitions get
;; magically connected to the primitives.

;; That works out because the top level here is just definitions, with
;; no top-level actions.

(make-trait miranda-trait me
  ({.selfie sink} (sink .write me))  
  (message (error "Message not understood" message me)))

(make-trait list-trait list
  ((i)
   (if (= i 0)
       list.first
       (list.rest (- i 1))))
  ({.empty?}
   (= 0 list.count)) ;N.B. these default implementations are circular
  ({.first}
   (list 0))
  ({.rest}
   (list .slice 1))
  ({.count}
   (if list.empty?
       0
       (+ 1 list.rest.count)))          ;TODO tail recursion
  ({.slice i}
   (assert (<= 0 i))
   (if (= i 0)
       list
       (list.rest .slice (- i 1))))
  ({.slice i bound}     ;XXX result is a cons-list; be more generic?
   (assert (<= 0 i))
   (case (list.empty? list)
         ((<= bound i) '())
         ((= i 0) (cons list.first (list.rest .slice 0 (- bound 1))))
         (else (list.rest .slice (- i 1) (- bound 1)))))
  ({.chain seq}
   (if list.empty?
       seq
       (cons list.first (list.rest .chain seq))))
  ({.compare xs}
   ;; N.B. mutable vectors compare by this method, so it's really a comparison as of right now
   (case (list.empty? (if xs.empty? 0 -1))
         (xs.empty? 1)
         (else (match (list.first .compare xs.first)
                 (0 (list.rest .compare xs.rest))
                 (d d)))))
  ;; A sequence is a kind of collection. Start implementing that:
  ({.keys}
   (range<- list.count))
  ({.values}
   list)
  ({.items}
   (enumerate list))
  ({.get key}
   (list .get key #no))
  ({.get key default}
   (if (and (integer? key) (<= 0 key) (not list.empty?))
       (begin walking ((k key) (xs rest))
         (case ((= k 0) xs.first)
               (xs.empty? default)
               (else (walking (- k 1) xs.rest))))
       default))
  ({.maps? key}
   (and (not list.empty?)
        (or (= 0 key)
            (and (< 0 key)
                 (list.rest .maps? (- key 1))))))
  ({.maps-to? value}
   (for some ((x list)) (= x value)))
  ({.find-key-for value}                  ;XXX name?
   (case (list.empty? (error "Missing key" value))
         ((= value list.first) 0)
         (else (+ 1 (list.rest .find-key-for value)))))
  )

(make-trait claim-primitive me
  ({.selfie sink}
   (sink .display (if me "#yes" "#no")))
  ({.compare a}   (case ((= me a) 0)    ;XXX untested. also, need to check that a is boolean.
                        (me       1)
                        (_       -1)))
  )

(make-trait procedure-primitive me
  )

(make-trait number-primitive me
  ({.+ a}         (__+ me a))
  ({.- a}         (__- me a))
  ({.* a}         (__* me a))
  ({.compare a}   (__number-compare me a))
  ({.quotient b}  (__quotient me b))
  ({.remainder b} (__remainder me b))
  ({.<< b}        (__bit-<<  me b))
  ({.>> b}        (__bit->>  me b))
  ({.not}         (__bit-not me))
  ({.and b}       (__bit-and me b))
  ({.or b}        (__bit-or  me b))
  ({.xor b}       (__bit-xor me b))
  ;; XXX sketchy support for 32-bit word ops:
  ({.u+ a}        (__u+ me a))
  ({.u/ a}        (__u/ me a))
  ({.u>> a}       (__u>> me a))
  ({.u<< a}       (__u<< me a))
  ({.s+ a}        (__s+ me a))
  ({.s* a}        (__s* me a))
  )

(make-trait symbol-primitive me
  ((actor @arguments)
   (call actor (term<- me arguments)))
  ({.name}        (__symbol->string me))
  ({.compare a}   (and (symbol? a)
                       (me.name .compare a.name)))
  )

(make-trait nil-primitive me
  ({.empty?}      #yes)
  ({.first}       (error "Empty list" '.first))
  ({.rest}        (error "Empty list" '.rest))
  ({.count}       0)
  ((i)            (error "Empty list" 'nth))
  ({.chain a}     a)
  ({.selfie sink} (sink .display "()"))
  (message        (list-trait me message))) ;XXX use trait syntax instead

(make-trait cons-primitive me
  ({.empty?}      #no)
  ({.first}       (__car me))
  ({.rest}        (__cdr me))
  ({.count}       (__length me))
  ((i)            (__list-ref me i))    ;XXX just use the trait method? then can e.g. mix lazy and eager list nodes
  ({.chain a}     (__append me a))
  ({.selfie sink}
   (sink .display "(")
   (sink .print me.first)
   (begin printing ((r me.rest))
     (case ((cons? r)
            (sink .display " ")
            (sink .print r.first)
            (printing r.rest))
           ((null? r))
           (else
            (sink .display " . ")       ;XXX we're not supporting this in read, iirc
            (sink .print r))))
   (sink .display ")"))
  (message
   (list-trait me message))) ;XXX use trait syntax instead

(make-trait vector-primitive me
  ({.empty?}      (= 0 me.count))
  ({.first}       (me 0))
  ({.rest}        (me .slice 1))
  ({.count}       (__vector-length me))
  ((i)            (__vector-ref me i))
  ({.maps? i}     (__vector-maps? me i))
  ({.chain v}     (__vector-append me v))
  ({.slice i}     (__subvector me i me.count))
  ({.slice i j}   (__subvector me i j))
  ({.set! i val}  (__vector-set! me i val))
  ({.copy! v}     (me .copy! v 0 v.count))
  ({.copy! v lo bound}
   ;; XXX range-check first
   (for each! ((i (range<- lo bound)))
     (__vector-set! me (- i lo) (v i)))) ;XXX was this what I wanted? I forget.
  ({.copy}        (__vector-copy me))
  ({.selfie sink}
   (sink .display "#")
   (sink .print (__vector->list me)))
  (message
   (list-trait me message))) ;XXX use trait syntax instead

(make-trait string-primitive me
  ({.empty?}      (= 0 me.count))
  ({.first}       (me 0))
  ({.rest}        (me .slice 1))
  ({.count}       (__string-length me))
  ((i)            (__string-ref me i))
  ({.maps? i}     (__string-maps? me i))
  ({.chain s}     (__string-append me s))
  ({.slice i}     (__substring me i me.count))
  ({.slice i j}   (__substring me i j))
  ({.compare s}
   (if (string? s)
       (__string-compare me s)          ; just a speedup
       (list-trait me {.compare s})))   ; but is this what we really want? (<=> "a" '(#\a))
  ({.join ss}   ;should this be a function, not a method?
   (if ss.empty?
       ss
       (foldr1 (given (x y) (chain x me y)) ss)))
  ;;XXX below mostly from list-trait, until .selfie
  ({.keys}        (range<- me.count))
  ({.values}      me)
  ({.items}       (enumerate me))
  ({.get key}     (me .get key #no))
  ({.get key default}
   (if (me .maps? key)
       (me key)
       default))
  ({.maps? key}
   (and (integer? key) (<= 0 key) (< key me.count)))
  ({.maps-to? value}
   (for some ((x list)) (= x value)))
  ({.find-key-for value}
   (unimplemented))                       ;XXX
  ({.trim-left}
   (if me.empty?
       me
       (do (let c me.first)
           (if c.whitespace?
               me.rest.trim-left
               me))))
  ({.trim-right}
   (begin scanning ((i me.count))
     (if (= i 0)
         ""
         (do (let c (me (- i 1)))
             (if c.whitespace?
                 (scanning (- i 1))
                 (me .slice 0 i))))))
  ({.trim}
   me.trim-left.trim-right)
  ({.split}
   (begin splitting ((s me.trim-left))
     (if s.empty?
         '()
         (do (let limit s.count)
             (begin scanning ((i 1))
               (case ((= i limit) `(,s))
                     (((s i) .whitespace?)
                      (cons (s .slice 0 i)
                            (splitting ((s .slice (+ i 1)) .trim-left))))
                     (else (scanning (+ i 1)))))))))
  ({.selfie sink}
   (sink .display #\")
   (for each! ((c me))
     (sink .display (match c            ;XXX super slow. We might prefer to use the Gambit built-in.
                      (#\\ "\\\\")
                      (#\" "\\\"")
                      (#\newline "\\n")
                      (#\tab     "\\t")
                      (#\return  "\\r")
                      (_ c))))
   (sink .display #\"))
  (message
   (list-trait me message))) ;XXX use trait syntax instead

(make-trait char-primitive me
  ({.code}        (__char->integer me))
  ({.letter?}     (__char-letter? me))
  ({.digit?}      (__char-digit? me))
  ({.whitespace?} (__char-whitespace? me))
  ({.alphanumeric?} (or me.letter? me.digit?))
  ({.compare c}   (__char-compare me c)) ;XXX untested
  )

(make-trait box-primitive me
  ({.^}           (__box-value me))
  ({.^= val}      (__box-value-set! me val))
  ({.selfie sink}
   (sink .display "<box ")
   (sink .print me.^)
   (sink .display ">"))
  )

(make-trait source-primitive me
  ({.read-char}   (__read-char me))
  ({.close}       (__close-port me))
  )

(make-trait sink-primitive me
  ({.display a}   (__display me a))
  ({.write a}     (__write me a))     ;XXX Scheme naming isn't very illuminating here
  ({.print a}     (a .selfie me))
  )

(make-trait term-primitive me
  ({.tag}         (__term-tag me))
  ({.arguments}   (__term-arguments me))
  ({.selfie sink}
   (sink .display "{")
   (sink .print me.tag)
   (for each! ((arg me.arguments))
     (sink .display " ")
     (sink .print arg))
   (sink .display "}"))
  ({.compare t}
   (`(,me.tag ,@me.arguments) .compare `(,t.tag ,@t.arguments))) ;XXX untested
  )

(make-trait void-primitive me
  ;; A Gambit type some operations return.
  )


;; Continuations

(define (__halt-cont)
  (make me {extending list-trait}
    ({.empty?}        #yes)
    ({.first}         (error "No more frames" me))
    ({.rest}          (error "No more frames" me))
    ({.selfie sink}   (sink .display "<halt-cont>"))))

(make-trait __cont-trait me
  ({.empty?}        #no)
  ({.selfie sink}   (sink .display "<cont>")) ;XXX more
  (message          (list-trait me message))) ;XXX use trait syntax instead

(define (__call-cont-standin-cont k message)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} '("XXX still a hack"))))

(define (__match-clause-cont k pat-r body rest-clauses object script datum message)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `((^ ,body) ,@rest-clauses))))

(define (__ev-trait-cont k r name trait clauses)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(make ,name ,trait ^
                 ,@clauses))))

(define (__ev-make-cont k name stamp-val r clauses)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(make ,name ^ #no   ; XXX as above
                 ,@clauses))))

(define (__ev-do-rest-cont k r e2)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} e2)))

(define (__ev-let-match-cont k r p)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(<match> ,p))))          ;XXX lousy presentation

(define (__ev-let-check-cont k val)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(<assert-matched-then> ',val))))

(define (__ev-arg-cont k r e2)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(^ ,e2))))

(define (__ev-call-cont k receiver)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(call ',receiver ^))))

(define (__ev-rest-args-cont k es r vals)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first}
     (define (quotify v) `',v)
     `(,@(each quotify (reverse vals)) ^ ,@es))))

(define (__ev-tag-cont k tag)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `{,tag ^^^})))

(define (__ev-and-pat-cont k r subject p2)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(<and-match?> ,p2))))

(define (__ev-view-call-cont k r subject p)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(: _ ^ ,p))))

(define (__ev-view-match-cont k r p)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} p)))

(define (__ev-match-rest-cont k r subjects ps)
  (make {extending __cont-trait}
    ({.rest} k)
    ({.first} `(<all-match?> ,@ps))))