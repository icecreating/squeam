;; A UI for cryptogram puzzles.
;; Ported from github.com/darius/sturm.

(import (use "lib/sturm")
  cbreak-mode get-key render
  cursor green red unstyled)
(import (use "lib/bag")
  bag<-)
(import (use "lib/random")
  random-rng<-)

(to (main args)
  (let cryptogram
    (match args.rest
      ('()     (random-encrypt (random-rng<-) (run-fortune)))
      (`(,str) str)
      (_       (error ("Usage: ~d [cryptogram]" .format (args 0))))))
  (for cbreak-mode ()
    (puzzle cryptogram)))

(let alphabet (each char<- ((#\a .code) .up-to (#\z .code)))) ;XXX clumsy

(to (random-encrypt rng text)
  (let values (array<-list alphabet))
  (rng .shuffle! values)
  (let code (map<- (zip alphabet values.values))) ;XXX why .values needed?
  (string<-list (for each ((ch text.lowercase))
                  (code .get ch ch))))

(to (run-fortune)
  ;; TODO ensure fits in sturm's width
  (shell-run "exec fortune"))

(to (shell-run command)                 ;; TODO extract to a library
  (let `(,from-stdout ,to-stdin ,pid) (open-subprocess command))
  ;; TODO do we have to wait for it to terminate?
  ;; XXX catch subprocess errors
  from-stdout.read-all)

(to (puzzle cryptogram)
  (let cv (cryptoview<- cryptogram))
  (begin playing ()
    (render (cv .view #yes))
    (let key (get-key))
    (match key
      ('esc (render (cv .view #no)))
      (_ (match key
           ('home      cv.go-to-start)
           ('end       cv.go-to-end)
           ('left      (cv .shift-by -1))
           ('right     (cv .shift-by  1))
           ('up        (cv .shift-line -1))
           ('down      (cv .shift-line  1))
           ('shift-tab (cv .shift-to-space -1))
           (#\tab      (cv .shift-to-space  1))
           ('backspace (cv .shift-by -1)
                       (cv .jot #\space))
           ('del       (cv .jot #\space)
                       (cv .shift-by 1))
           (_ (case ((or (= key #\space) (alphabet .find? key))
                     (cv .jot key)
                     (cv .shift-by 1))
                    ((and (char? key) key.uppercase?)
                     (cv .shift-to-code 1 key)))))
         (playing)))))

(to (cryptoview<- cryptogram)

  (let code (those '.letter? cryptogram.uppercase))
  (surely (not code.empty?))            ;XXX 'require' or something
  (let decoder
    (map<- (for each ((ch ((call set<- code) .keys))) ;XXX clumsy
             `(,ch #\space))))
  (let point (box<- 0))                ; Index in `code` of the cursor

  (let lines (each clean cryptogram.uppercase.split-lines))
  (let line-starts
    (running-sum (for each ((line lines))
                   ((those '.letter? line) .count))))

  (to (shift-by offset)
    (point .^= ((+ point.^ offset) .modulo code.count)))

  (to (shift-till offset stop?)
    (shift-by offset)
    (unless (stop?)
      (shift-till offset stop?)))

  (make _
    ({.jot letter}
     (decoder .set! (code point.^) letter))

    ({.go-to-start}
     (point .^= 0))

    ({.go-to-end}
     (point .^= (- code.count 1)))

    ({.shift-by offset}
     (shift-by offset))

    ({.shift-line offset}
     (shift-till offset (given () (line-starts .find? point.^))))

    ({.shift-to-space offset}
     (when (decoder.values .find? #\space)
       (shift-till offset (given () (= #\space (decoder (code point.^)))))))

    ({.shift-to-code offset letter}
     (when (code .find? letter)
       (shift-till offset (given () (= letter (code point.^))))))

    ({.view show-cursor?}
     (let counts (call bag<- (for those ((v decoder.values))
                               (not= v #\space))))
     (let letters-left (for each ((ch alphabet))
                         (if (counts .maps? ch) #\space ch)))
     (let clashes (call set<- (for filter ((`(,v ,n) counts.items))
                                (and (< 1 n) v))))

     (let pos (box<- 0))

     (let view (flexarray<-))
     (to (emit x) (view .push! x))

     (emit (green `("Free: " ,letters-left #\newline)))
     (for each! ((line lines))
       (emit #\newline)
       (for each! ((ch line))
         (when (and show-cursor? ch.letter?)
           (when (= pos.^ point.^)
             (emit cursor))
           (pos .^= (+ pos.^ 1)))         ;XXX clumsier
         (emit (decoder .get ch ch)))
       (emit #\newline)
       (for each! ((ch line))
         (emit (if ch.letter? #\- #\space)))
       (emit #\newline)
       (for each! ((ch line))
         (let color (case ((clashes .maps? (decoder .get ch)) red)
                          ((= ch (code point.^))              green)
                          (else                               unstyled)))
         (emit (color ch)))
       (emit #\newline))

     (as-list view))))

;; Expand tabs; blank out other control characters.
(to (clean str)
  (let r (flexarray<-))
  (for each! ((ch str))
    (case ((= ch #\tab)
           (begin padding ()
             (r .push! #\space)
             (unless (= 0 (r.count .modulo 8))
               (padding))))
          ((< ch.code 32)
           (r .push! #\space))
          (else
           (r .push! ch))))
  (string<-list (as-list r)))           ;XXX clumsy

(to (running-sum numbers)
  (let sums (flexarray<- 0))
  (for each! ((n numbers))
    (sums .push! (+ sums.last n)))
  sums)

(export main)
