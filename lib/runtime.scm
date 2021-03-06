;; This special source file must be written to load without actually
;; invoking any primitive object, because this code *defines* their
;; scripts. Only after this file is loaded will the definitions get
;; magically connected to the primitives.

;; That works out because the top level here is just definitions, with
;; no top-level actions.

;; There's also a definition of map<-, needed to implement (export ...).

;; Aaand this includes further definitions used by the above-needed
;; definitions, transitively.

(make-trait miranda-trait me
  ({.selfie sink} (__write me sink))
  (message (error "Match failure" me message)))

(make-trait list-trait list
  (`(,i)
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
   (surely (<= 0 i))
   (if (= i 0)
       list
       (list.rest .slice (- i 1))))
  ({.slice i bound}     ;XXX result is a cons-list; be more generic?
   (surely (<= 0 i))
   (case (list.empty? list)
         ((<= bound i) '())
         ((= i 0) (cons list.first (list.rest .slice 0 (- bound 1))))
         (else (list.rest .slice (- i 1) (- bound 1)))))
  ({.chain seq}                         ;TODO self if seq is ()
   (if list.empty?
       seq
       (cons list.first (list.rest .chain seq))))
  ({.compare xs}
   ;; N.B. mutable arrays compare by this method, so it's really a comparison as of right now
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
   (if (and (integer? key) (<= 0 key))
       (begin walking ((k key) (xs list))
         (case (xs.empty? default)
               ((= k 0) xs.first)
               (else (walking (- k 1) xs.rest))))
       default))
  ({.maps? key}
   (and (not list.empty?)
        (or (= 0 key)
            (and (< 0 key)
                 (list.rest .maps? (- key 1))))))
  ({.find value default}    ;; XXX update the other collections to have this too
   (begin looking ((i 0) (values list))
      (case (values.empty? default)
            ((= value values.first) i)
            (else (looking (+ i 1) values.rest)))))   
  ({.find value}
   (match (list .find value #no)
     (#no (error "Missing value" value))
     (key key)))
  ({.find? value}
   (match (list .find value #no)
     (#no #no)
     (_ #yes)))
  ({.last}
   (let rest list.rest)
   (if rest.empty? list.first rest.last))
  ({.repeat n}
   ;;TODO a method to get an empty seq of my type; and then factor out duplicate code
   (match n
     (0 '())             
     (_ (call chain (for each ((_ (range<- n)))
                      list)))))
  )

(make-trait claim-primitive me
  ({.selfie sink}
   (sink .display (if me "#yes" "#no")))
  ({.compare a}
   (and (claim? a)
        (case ((= me a) 0)
              (me       1)
              (else    -1))))
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
  ({.modulo b}    (__modulo me b))
  ({.*/mod m d}   (__*/mod me m d))
  ({./mod d}      (__*/mod me 1 d))
  ({.<< b}        (__bit-<<  me b))
  ({.>> b}        (__bit->>  me b))
  ({.not}         (__bit-not me))
  ({.and b}       (__bit-and me b))
  ({.or b}        (__bit-or  me b))
  ({.xor b}       (__bit-xor me b))
  ({.up-to< b}    (range<- me b))
  ({.up-to b}     (range<- me (+ b 1)))
  ;; XXX sketchy support for 32-bit word ops:
  ({.u+ a}        (__u+ me a))
  ({.u- a}        (__u- me a))
  ({.u>> a}       (__u>> me a))
  ({.u<< a}       (__u<< me a))
  ({.s+ a}        (__s+ me a))
  ({.s* a}        (__s* me a))
  )

(make-trait symbol-primitive me
  (`(,actor ,@arguments)
   (call actor (term<- me arguments)))
  ({.name}        (__symbol->string me))
  ({.compare a}   (and (symbol? a)
                       (me.name .compare a.name)))
  ({.selfie sink} (sink .display me.name))
  )

(make-trait nil-primitive me
  ({.empty?}      #yes)
  ({.first}       (error "Empty list" '.first))
  ({.rest}        (error "Empty list" '.rest))
  ({.count}       0)
  (`(,i)          (error "Empty list" 'nth i))
  ({.chain a}     a)
  ({.selfie sink} (sink .display "()"))
  (message        (list-trait me message))) ;XXX use trait syntax instead

(make-trait cons-primitive me
  ({.empty?}      #no)
  ({.first}       (__car me))
  ({.rest}        (__cdr me))
  ({.count}       (__length me))
  (`(,i)          (__list-ref me i))    ;XXX just use the trait method? then can e.g. mix lazy and eager list nodes
  ({.chain a}     (__append me a))
  ({.selfie sink}
   (sink .display "(")
   (sink .print me.first)
   (begin printing ((r me.rest))
     (case ((cons? r)
            (sink .display " ")
            (sink .print r.first)
            (printing r.rest))
           ((null? r) 'ok)
           (else
            (sink .display " . ")       ;XXX we're not supporting this in read, iirc
            (sink .print r))))
   (sink .display ")"))
  (message
   (list-trait me message))) ;XXX use trait syntax instead

(make-trait array-trait me
  ({.slice i}
   (me .slice i me.count))
  ({.slice i bound}
   (let v (array<-count (- bound i)))
   (for each! ((j bound))
     (v .set! j (me (+ i j))))
   v)
  ({.last}
   (me (- me.count 1)))
  ({.copy! v}
   (me .copy! v 0 v.count))
  ({.move! dest src len}                ;XXX untested
   (for each! ((i (if (<= dest src)
                      (range<- len)
                      (reverse (range<- len)))))  ;TODO inefficient
     (me .set! (+ dest i)
         (me (+ src i)))))
  ({.values}
   (for each ((i (range<- me.count)))   ;TODO cheaper to represent by self -- when can we get away with that?
     (me i)))
  ({.items}
   (for each ((i (range<- me.count)))
     `(,i ,(me i))))
;  ({.get key default}  TODO custom impl
  ({.swap! i j}
   (let t (me i))
   (me .set! i (me j))
   (me .set! j t))
  (message
   (list-trait me message))) ;XXX use trait syntax instead

(make-trait array-primitive me
  ({.empty?}      (= 0 me.count))
  ({.first}       (me 0))
  ({.rest}        (me .slice 1))
  ({.count}       (__vector-length me))
  (`(,i)          (__vector-ref me i))
  ({.maps? i}     (__vector-maps? me i))
  ({.chain v}     (__vector-append me v))
  ({.slice i}     (__subvector me i me.count))
  ({.slice i j}   (__subvector me i j))
  ({.set! i val}  (__vector-set! me i val))
  ({.copy! v lo bound}
   ;; XXX range-check first
   (for each! ((i (range<- lo bound)))
     (__vector-set! me (- i lo) (v i)))) ;XXX was this what I wanted? I forget.
  ({.copy}        (__vector-copy me))
  ({.selfie sink}
   (sink .display "#")
   (sink .print (__vector->list me)))
  (message
   (array-trait me message))) ;XXX use trait syntax instead

(make-trait string-primitive me
  ({.empty?}      (= 0 me.count))
  ({.first}       (me 0))
  ({.rest}        (me .slice 1))
  ({.count}       (__string-length me))
  (`(,i)          (__string-ref me i))
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
       ""
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
  ({.maps? key}                         ;XXX duplicate, see above
   (and (integer? key) (<= 0 key) (< key me.count)))
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
  ({.split delimiter}
   ;; TODO deduplicate code
   (begin splitting ((s me))
     (if s.empty?
         '()
         (do (let limit s.count)
             (begin scanning ((i 0))
               (case ((= i limit) `(,s))
                     ((= delimiter (s .slice i (+ i delimiter.count)))
                      (cons (s .slice 0 i)
                            (splitting (s .slice (+ i delimiter.count)))))
                     (else (scanning (+ i 1)))))))))
  ({.lowercase} (string<-list (for each ((c me)) c.lowercase)))
  ({.uppercase} (string<-list (for each ((c me)) c.uppercase)))
  ({.starts-with? s}
   (= (me .slice 0 s.count) s))   ;TODO more efficient
  ({.replace pattern replacement} ;TODO more efficient
   ;; TODO unify the cases?
   (case (pattern.empty?
          (for foldr ((ch me) (rest replacement))
            (chain replacement (string<- ch) rest)))
         (else
          (let limit me.count)
          (string<-list
           (begin scanning ((i 0))
             (case ((= i limit) '())
                   ((= pattern (me .slice i (+ i pattern.count)))
                    (chain (list<-string replacement)
                           (scanning (+ i pattern.count))))
                   (else (cons (me i) (scanning (+ i 1))))))))))
  ({.justify n}
   (me .justify n #\space))
  ({.justify n pad}
   (if (< n 0)
       (me .left-justify (- n) pad)
       (me .right-justify n    pad)))
  ({.left-justify n}
   (me .left-justify n #\space))
  ({.left-justify n pad-char}
   (let pad (- n me.count))
   (if (<= pad 0)
       me
       (chain me ((string<- pad-char) .repeat pad))))
  ({.right-justify n}
   (me .right-justify n #\space))
  ({.right-justify n pad-char}
   (let pad (- n me.count))
   (if (<= pad 0)
       me
       (chain ((string<- pad-char) .repeat pad) me)))
  ({.center n}
   (let pad (- n me.count))
   (if (<= pad 0)
       me
       (do (let half (pad .quotient 2))
           (chain (" " .repeat (- pad half))
                  me
                  (" " .repeat half)))))
  ({.repeat n}
   (match n
     (0 "")
     (_ (call chain (for each ((_ (range<- n)))
                      me)))))
  ({.format @arguments}
   (let sink (string-sink<-))
   (call format `{.to ,sink ,me ,@arguments})
   sink.output-string)
  ({.split-lines}
   (me .split "\n"))
  ({.selfie sink}
   (sink .display #\")
   (for each! ((c me))
     (sink .display (match c            ;XXX super slow. We might prefer to use the Gambit built-in.
                      (#\\ "\\\\")
                      (#\" "\\\"")
                      (#\newline "\\n")
                      (#\tab     "\\t")
                      (#\return  "\\r")
                      ;; XXX escape the control chars
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
  ({.lowercase?}  (__char-lowercase? me))
  ({.uppercase?}  (__char-uppercase? me))
  ({.lowercase}   (__char-lowercase me))
  ({.uppercase}   (__char-uppercase me))
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
  ({.read-all}    (__read-all me))
  ({.close}       (__close-port me))
  ({.ready?}      (__char-ready? me))
  ({.read-line}
   (let ch me.read-char)
   (if (eof? ch)
       ch
       (string<-list
        (begin reading ((ch ch))
          (if (or (eof? ch) (= ch #\newline))
              '()
              (cons ch (reading me.read-char)))))))
  )

(make-trait sink-primitive me
  ({.display a}   (__display a me))
  ({.print a}     (a .selfie me))
  ({.close}       (__close-port me))
  ({.output-string}                 ;XXX for string-sink only
   (__get-output-string me))
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
  ;; A Gambit type returned by some of the Gambit operations.
  )

(make-trait script-primitive me
  ({.name}    (__script-name me))
  ({.trait}   (__script-trait me))
  ({.clauses} (__script-clauses me))
  ({.selfie sink}
   (sink .display "<script ")
   (sink .display me.name)
   (sink .display ">"))
  )

(make-trait cps-primitive me
  ({.selfie sink}
   (sink .display "#<primitive ")
   (sink .display (__cps-primitive-name me))
   (sink .display ">"))
  )

(make-trait ejector-primitive me
  ({.eject value}
   (__eject me value))
  ({.selfie sink}
   (sink .display "#<ejector>"))
  )


;; Continuations

(to (__unexp e)         (unparse-exp (__expr e)))
(to (__unpat p)         (unparse-pat (__patt p)))
(to (__unclause clause) (unparse-clause (__clause clause)))

(to (__clause `(,p ,pv ,ev ,e))
  `(,(__patt p) ,pv ,ev ,(__expr e)))

(make-trait __halt-cont me
  ({.empty?}        #yes)
  ({.first}         (error "No more frames" me))
  ({.rest}          (error "No more frames" me))
  ({.selfie sink}   (sink .display "<halt-cont>"))
  (message (list-trait me message)))

(make-trait __cont-trait me   ;; For the non-halt cont types
  ({.empty?}        #no)
  ({.rest}          (__cont-next-cont me)) ;TODO
  ({.selfie sink}   (sink .display "<cont>")) ;TODO at least give out the tag
  ({.env}
   ((__cont-data me) .first)) ; Commonly this, but sometimes needs to be overridden.
  (message
   (list-trait me message))) ;XXX use trait syntax instead

(make-trait __match-clause-cont me
  ({.first}
   (let `(,pat-r ,body ,rest-clauses ,object ,script ,datum ,message) (__cont-data me))
   `((^ ,(__unexp (body 1)))
     ,@(each __unclause rest-clauses)))
  (message
   (__cont-trait me message)))

(make-trait __ev-make-cont me
  ({.first}
   (let `(,r ,name ,clauses) (__cont-data me))
   `(make ,name ^
      ,@(each __unclause clauses)))
  (message
   (__cont-trait me message)))

(make-trait __ev-do-rest-cont me
  ({.first}
   (let `(,r ,e2) (__cont-data me))
   (__unexp e2))
  (message
   (__cont-trait me message)))

(make-trait __ev-let-match-cont me
  ({.first}
   (let `(,r ,p) (__cont-data me))
   `(<match> ,(__unpat p)))          ;XXX lousy presentation
  (message
   (__cont-trait me message)))

(make-trait __ev-let-check-cont me
  ({.first}
   (let `(,val) (__cont-data me))
   `(<assert-matched-then> ',val))
  ({.env}
   '())
  (message
   (__cont-trait me message)))

(make-trait __ev-arg-cont me
  ({.first}
   (let `(,r ,e2) (__cont-data me))
   `(^ ,(__unexp e2)))
  (message
   (__cont-trait me message)))

(make-trait __ev-call-cont me
  ({.first}
   (let `(,receiver) (__cont-data me))
   `(call ',receiver ^))
  ({.env}
   '())
  (message
   (__cont-trait me message)))

(make-trait __ev-rest-args-cont me
  ({.first}
   (let `(,r ,es ,vals) (__cont-data me))
   (to (quotify v) `',v)
   `(,@(each quotify (reverse vals)) ^ ,@(each __unexp es)))
  (message
   (__cont-trait me message)))

(make-trait __ev-tag-cont me
  ({.first}
   (let `(,tag) (__cont-data me))
   `{,tag ^^^})
  ({.env}
   '())
  (message
   (__cont-trait me message)))

(make-trait __ev-and-pat-cont me
  ({.first}
   (let `(,r ,subject ,p2) (__cont-data me))
   `(<and-match?> ,(__unpat p2)))
  (message
   (__cont-trait me message)))

(make-trait __ev-view-call-cont me
  ({.first}
   (let `(,r ,subject ,p) (__cont-data me))
   `(? _ ^ ,(__unpat p)))
  (message
   (__cont-trait me message)))

(make-trait __ev-view-match-cont me
  ({.first}
   (let `(,r ,p) (__cont-data me))
   (__unpat p))
  (message
   (__cont-trait me message)))

(make-trait __ev-match-rest-cont me
  ({.first}
   (let `(,r ,subject ,ps) (__cont-data me))
   `(<all-match?> ,@(each __unpat ps)))
  (message
   (__cont-trait me message)))

(make-trait __unwind-cont me
  ({.first}
   '<unwind>)                           ;TODO show more
  ({.env}
   '())
  (message
   (__cont-trait me message)))

(make-trait __replace-answer-cont me
  ({.first}
   (let `(,value) (__cont-data me))
   `(<replace-answer> ',value))
  ({.env}
   '())
  (message
   (__cont-trait me message)))


;; Hash-maps
;; This is defined in the runtime, here, because the form
;; (export foo bar) gets expanded into code like
;;   (map<- `((foo ,foo) (bar ,bar))) 
;; (but hygienic).

;; TODO:
;;   test deletion more
;;   nonlinear probing -- how about xor probing?
;;   preserving insertion order
;;   immutable snapshots
;;
;;   impl without a million boxes
;;   N.B. impl needs shared closures for efficiency
;;        (capacity, occupants, ..., hashmap)
;;   special-case impls for small maps and common-typed maps
;;   store hash codes instead of recomputing?
;;   etc.

(let map<-
  (hide

    (make none)
    (make deleted)

    (make map<-

      ('()
       (let count (box<- 0))
       (let keys  (box<- (array<- none)))  ;; size a power of 2
       (let vals  (box<- (array<- #no)))   ;; same size

       (to (capacity) keys.^.count)

       (to (occupants)
         (begin walking ((i (- (capacity) 1)))
           (if (< i 0)
               '()
               (do (let k (keys.^ i))
                   (case ((= k none) (walking (- i 1)))
                         ((= k deleted) (walking (- i 1)))
                         (else (cons i (walking (- i 1)))))))))

       (to (place key)
         (let mask (- keys.^.count 1))
         (let i0   (mask .and (__hash key)))
         (begin walking ((i i0)
                         (slot #no)) ;if integer, then where to put the key if missing
           (let k (keys.^ i))
           (case ((= k none) {missing-at (or slot i)})
                 ((= k key)  {at i})
                 (else
                  (let j (mask .and (- i 1)))
                  (if (= j i0)
                      (if slot {missing-at slot} (error "Can't happen"))
                      (walking j (or slot (and (= k deleted) i))))))))

       (to (maybe-grow)
         (when (< (* 2 (capacity))
                  (* 3 count.^))
           (resize (* 2 (capacity)))))

       (to (resize new-capacity)
         (let old-keys keys.^)
         (let old-vals vals.^)
         (keys .^= (array<-count new-capacity none))
         (vals .^= (array<-count new-capacity))
         (for each! ((`(,i ,key) old-keys.items))
           (unless (or (= key none) (= key deleted))
             (let {missing-at j} (place key))
             (keys.^ .set! j key)
             (vals.^ .set! j (old-vals i)))))
       
       (make hashmap
         (`(,key)
          (match (place key)
            ({at i} (vals.^ i))
            (_      (error "Missing key" hashmap key))))
         ({.get key @(optional default)}
          (match (place key)
            ({at i} (vals.^ i))
            (_      default)))
         ({.set! key val}
          (match (place key)
            ({at i}
             (vals.^ .set! i val))
            ({missing-at i}
             (keys.^ .set! i key)
             (vals.^ .set! i val)
             (count .^= (+ count.^ 1))
             (maybe-grow))))
         ({.maps? key}
          (match (place key)
            ({at _} #yes)
            (_      #no)))
         ({.empty?} (= count.^ 0))
         ({.count}  count.^)
         ({.keys}   (each keys.^ (occupants))) ;XXX lazy-map
         ({.values} (each vals.^ (occupants)))
         ({.items}
          (let ks keys.^)
          (let vs vals.^)
          (for each ((i (occupants)))
            `(,(ks i) ,(vs i))))
         ({.delete! key}
          (match (place key)
            ({at i}
             (keys.^ .set! i deleted)
             (count .^= (- count.^ 1))
             #no)
            (_ #no)))
         ({.find? value}
          (hashmap.values .find? value))
         ({.find value default}
          (let vs vals.^)
          (begin searching ((js (occupants)))  ;XXX should be lazy
            (case (js.empty? default)
                  ((= value (vs js.first)) (keys.^ js.first))
                  (else (searching js.rest)))))
         ({.clear!}
          (count .^= 0)
          (keys .^= (array<- none))
          (vals .^= (array<- #no)))
         ({.selfie sink}
          (sink .display "#<hash-map (")
          (sink .print count.^)
          (sink .display ")>"))
         ))

      (`(,a-list) ;TODO invent a concise constructor; frozen by default
       (let m (map<-))
       (for each! ((`(,k ,v) a-list))
         (m .set! k v))
       m))))


;; stdlib

(to (surely ok? @arguments)
  (unless ok?
    (call error (if arguments.empty? '("Assertion failed") arguments))))

(to (not= x y)
  (not (= x y)))

(make +
  (`() 0)
  (`(,a) a)
  (`(,a ,b) (a .+ b))
  (`(,a ,b ,@arguments) (foldl '.+ (a .+ b) arguments)))

(make *
  (`() 1)
  (`(,a) a)
  (`(,a ,b) (a .* b))
  (`(,a ,b ,@arguments) (foldl '.* (a .* b) arguments)))

(make -
  (`() (error "Bad arity"))
  (`(,a) (0 .- a))
  (`(,a ,b) (a .- b))
  (`(,a ,b ,@arguments) (foldl '.- (a .- b) arguments)))

(make-trait transitive-comparison compare?
  (`(,x ,@xs)
   (begin comparing ((x0 x) (xs xs))
     (match xs
       (`() #yes)
       (`(,x1 ,@rest) (and (compare? x0 x1)
                           (comparing x1 rest)))))))

(make <   {extending transitive-comparison} (`(,a ,b)      (= (compare a b) -1)))
(make <=  {extending transitive-comparison} (`(,a ,b) (not (= (compare a b)  1))))
(make <=> {extending transitive-comparison} (`(,a ,b)      (= (compare a b)  0))) ; XXX better name?
(make >=  {extending transitive-comparison} (`(,a ,b) (not (= (compare a b) -1))))
(make >   {extending transitive-comparison} (`(,a ,b)      (= (compare a b)  1)))

(to (compare a b)
  (let result (a .compare b))
  (if (comparison? result) result (error "Incomparable" a b)))

(to (comparison? x)
  (match x
    (-1 #yes)
    ( 0 #yes)
    (+1 #yes)
    (_  #no)))


;;XXX so should some of these be in list-trait?

(to (reverse xs)
  (for foldl ((ys '()) (x xs))
    (cons x ys)))

(to (foldl f z xs)
  (if xs.empty?
      z
      (foldl f (f z xs.first) xs.rest)))

(to (foldr f xs z)     ;TODO rename since args are in nonstandard order
  (if xs.empty?
      z
      (f xs.first (foldr f xs.rest z))))

(to (foldr1 f xs)
  (let tail xs.rest)
  (if tail.empty?
      xs.first
      (f xs.first (foldr1 f tail))))

(to (each f xs)
  (for foldr ((x xs) (ys '()))
    (cons (f x) ys)))

(to (gather f xs)
  (for foldr ((x xs) (ys '()))
    (chain (f x) ys)))

(to (those ok? xs)
  (for foldr ((x xs) (ys '()))
    (if (ok? x) (cons x ys) ys)))

(to (filter f xs)             ;TODO is this worth defining? good name?
  (those identity (each f xs)))

(to (list<- @arguments)
  arguments)

(make chain
  (`() '())
  (`(,xs) xs)
  (`(,xs ,ys) (xs .chain ys))
  (`(,@arguments) (foldr1 '.chain arguments)))

(to (some ok? xs)
  (and (not xs.empty?)
       (or (ok? xs.first)
           (some ok? xs.rest))))

(to (every ok? xs)
  (or xs.empty?
      (and (ok? xs.first)
           (every ok? xs.rest))))

(to (each! f xs)
  (unless xs.empty?
    (f xs.first)
    (each! f xs.rest)))

(to (identity x)
  x)

(make range<-
  (`(,limit)
   (range<- 0 limit))
  (`(,first ,limit)
   (if (<= limit first)
       '()
       (make range {extending list-trait}
         ({.empty?} #no)
         ({.first}  first)
         ({.rest}   (range<- (+ first 1) limit))
         ({.count}  (- limit first))
         (`(,i)
          (if (not (integer? i))
              (error "Key error" range i)
              (do (let j (+ first i))
                  (if (and (<= first j) (< j limit))
                      j
                      (error "Out of range" range i)))))
         ({.maps? i}
          (and (integer? i)
               (do (let j (+ first i))
                   (and (<= first j) (< j limit)))))
         )))
  (`(,first ,limit ,stride)
   (unless (< 0 stride)
     (error "TODO downward range" stride))
   (if (<= limit first)
       '()
       (make range {extending list-trait}
         ({.empty?} #no)
         ({.first}  first)
         ({.rest}   (range<- (+ first stride) limit stride))
         (`(,i)
          (error "TODO" range `(,i)))
         ({.maps? i}
          (error "TODO" range {.maps? i}))
         ))))

(make enumerate
  (`(,xs)
   (enumerate xs 0))
  (`(,xs ,i)
   (if xs.empty?
       '()
       (make enumeration {extending list-trait}
         ({.empty?} #no)
         ({.first}  `(,i ,xs.first))
         ({.rest}   (enumerate xs.rest (+ i 1)))))))

(to (array<- @elements)
  (array<-list elements))

(to (string<- @chars)
  (string<-list chars))

(to (with-output-string take-sink)             ;TODO rename
  (let sink (string-sink<-))
  (take-sink sink)
  sink.output-string)


;; (Roughly) undo parse-exp and parse-pat.
;; Really we should track source-position info instead, and report that.
;; This is just to make debugging less painful till then.

(let (list<- unparse-exp unparse-pat unparse-clause)
  (hide

    (to (unparse-exp e)
      (match e.term
        ({constant c}
         (if (self-evaluating? c) c `',c))
        ({variable v}
         v)
        ({make name stamp trait clauses}
         (unparse-make name stamp trait clauses))
        ({do e1 e2}
         (unparse-do e1 e2))
        ({let p e}
         `(let ,(unparse-pat p) ,(unparse-exp e)))
        ({call e1 e2}
         (match e2.term
           ({list operands}
            `(,(unparse-exp e1) ,@(each unparse-exp operands)))
           ({term (? cue? cue) operands}
            `(,(unparse-exp e1) ,cue ,@(each unparse-exp operands)))
           (_
            `(call ,(unparse-exp e1) ,(unparse-exp e2)))))
        ({term tag es}
         (term<- tag (each unparse-exp es)))
        ({list es}
         `(list<- ,@(each unparse-exp es))))) ;XXX unhygienic

    (to (unparse-do e1 e2)
      (let es
        (begin unparsing ((tail e2))
          (match tail.term
            ({do e3 e4} (cons e3 (unparsing e4)))
            (_ `(,tail)))))
      `(do ,@(each unparse-exp (cons e1 es))))

    (to (unparse-make name stamp trait-term clauses)
      (surely (= {constant #no} stamp.term)) ;XXX
      `(make ,name
         ,@(match trait-term.term
             ({constant #no} '())
             (trait-e `({extending ,(unparse-exp trait-e)})))
         ,@(each unparse-clause clauses)))

    (to (unparse-clause `(,p ,p-vars ,e-vars ,e))
      `(,(unparse-pat p) ,(unparse-exp e)))

    (to (self-evaluating? x)
      (or (claim? x)
          (number? x)
          (char? x)
          (string? x)))

    (to (unparse-pat pat)
      ;; XXX these need updating to the newer pattern syntax
      (match pat.term
        ({constant-pat c}
         (if (self-evaluating? c) c `',c))
        ({any-pat}
         '_)
        ({variable-pat v}
         v)
        ({term-pat tag ps}
         (term<- tag (each unparse-pat ps)))
        ({list-pat ps}
         (each unparse-pat ps))
        ({and-pat p1 p2}
         `(<and-pat> ,(unparse-pat p1) ,(unparse-pat p2)))
        ({view-pat e p}
         `(<view-pat> ,(unparse-exp e) ,(unparse-pat p)))))

    (list<- unparse-exp unparse-pat unparse-clause)))


;; printf-ish thing. TODO do something completely different?
(let format
  (hide

    (make format
      (`(,format-string ,@arguments)
       (scanning out format-string arguments))
      ({.to sink format-string @arguments}
       (scanning sink format-string arguments)))

    ;;TODO actually design the format language

    (to (scanning sink s args)
      (if s.empty? 
          (unless args.empty?
            (error "Leftover arguments" args))
          (match s.first
            (#\~
             (let ss s.rest)
             (if (ss .starts-with? "-")
                 (parse sink ss.rest -1 #no args)
                 (parse sink ss #no #no args)))
            (ch
             (sink .display ch)
             (scanning sink s.rest args)))))

    (to (parse sink s sign width args)
      (if (s .starts-with? "0")
          (parsing sink s.rest #\0     sign width args)
          (parsing sink s      #\space sign width args)))

    (to (parsing sink s pad sign width args)
      (when s.empty?
        (error "Incomplete format")) ;TODO report the format-string
      (match s.first
        (#\w
         (maybe-pad sink pad sign width {.print args.first})
         (scanning sink s.rest args.rest))
        (#\d
         (maybe-pad sink pad sign width {.display args.first})
         (scanning sink s.rest args.rest))
        (#\~
         (sink .display "~")
         (scanning sink s.rest args))
        ((? '.digit? ch)
         (let digit (- ch.code 48))
         (parsing sink s.rest pad sign      ;TODO testme with a multidigit width
                  (+ (if width (* 10 width) 0)
                     digit)
                  args))
        (_
         (error "Bad format string" s))))

    (to (maybe-pad sink pad sign width message)
      (case (width
             (sink .display ((with-output-string (given (o) (call o message)))
                             .justify (if sign (* sign width) width)
                                      pad)))
            (sign
             (error "Missing width in format string"))
            (else
             (call sink message))))

    format))
