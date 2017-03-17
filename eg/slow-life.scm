;; Game of Life

(import (use "lib/sturm")
  cbreak-mode)
(import (use "later/ansi-term")
  home clear-screen cursor-show cursor-hide)

(to (main (prog @args))
  (let n-steps (match args
                 (() 20)
                 ((n-str) (number<-string n-str))
                 (_ (error ("Usage: ~d [#steps]" .format prog)))))
  (let grid (grid<- 24 39))
  (paint grid 10 18 '(" **"             ;TODO: read in a pattern
                      "** "
                      " * "))
  (for cbreak-mode ()
    (display cursor-hide)
    (begin running ((grid grid) (step 0))
      (display clear-screen)
      (display home)
      (show grid)
      (when (< step n-steps)
        (running grid.next (+ step 1))))
    (display cursor-show)))

(to (paint grid top left lines)
  (for each! (((i line) lines.items))
    (for each! (((j ch) line.items))
      (grid .set! (+ top i) (+ left j)
            (if ch.whitespace? 0 1)))))

(to (show grid)
  (for each! ((row grid.view))
    (for each! ((value row))
      (display (" O" value))
      (display " "))
    (newline)))

(to (grid<- n-rows n-cols)

  ;; G is an array storing, for each Life grid cell, its value (0 or
  ;; 1). It has two extra rows and columns for the edges.
  (let R (+ n-rows 2))
  (let C (+ n-cols 2))
  (let G (vector<-count (* R C) 0))

  (let N (- C))
  (let S C)
  (let W (- 1))
  (let E 1)
  (let neighbor-dirs
    `(,(+ N W) ,N ,(+ N E)
      ,W          ,E
      ,(+ S W) ,S ,(+ S E)))

  ;; r in [1..n-rows], c in [1..n-cols].
  (to (at r c)
    (+ (* C r) c))

  (to (update i)
    (match (sum (for each ((dir neighbor-dirs))
                  (G (+ i dir))))
      (2 (G i))
      (3 1)
      (_ 0)))

  ;; Make the world toroidal by copying the edges of the array so that
  ;; row #1 effectively neighbors row #n-rows, and likewise for the
  ;; columns.
  ;; XXX wrong on top edge, at least
  (to (copy-edges)
    (for each! ((r (range<- 1 (+ n-rows 1))))
      (G .set! (at r 0)       (G (at r n-cols)))
      (G .set! (at r (- C 1)) (G (at r 1))))
    (G .copy! (at 0 0)       (at n-rows 0) C)
    (G .copy! (at (- R 1) 0) (at 1 0)      C))

  (make life-grid
    ((r c)
     (G (at r c)))
    ({.set! r c value}
     (surely ('(0 1) .find? value))
     (G .set! (at r c) value))
    ({.view}
     (for each ((r (range<- 1 (+ n-rows 1))))
       (for each ((c (range<- 1 (+ n-cols 1))))
         (G (at r c)))))
    ({.next}
     (copy-edges)
     (let new (grid<- n-rows n-cols))
     (for each ((r (range<- 1 (+ n-rows 1))))
       (for each ((c (range<- 1 (+ n-cols 1))))
         (new .set! r c (update (at r c)))))
     new)
    ))

(export grid<- paint show)
