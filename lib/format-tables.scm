;; Format a sequence of strings in columns.
;; Based on github.com/darius/columnize

;; Given a list of rows, each a list of strings, return a list of lines.
;; Each line is the corresponding row joined by `separator`, with each
;; column padded to its max width.
(to (format-table rows separator @(optional opt-justify))
  (let justify (or opt-justify '.left-justify))
  (surely (for every ((row rows))
            (= row.count ((rows 0) .count))))
  (let widths (for each ((column (transpose rows)))
                (call max (each '.count column))))
  (for each ((row rows))
    (separator .join (for each ((`(,string ,width) (zip row widths)))
                       (justify string width)))))

;; Given a sequence of strings, return a matrix of the same strings in
;; column order, trying to fit them in the given width.
(to (tabulate strings width)
  (let max-width (+ 2 (call max `(0 ,@(each '.count strings)))))
  (let n-cols (max 1 (min strings.count (width .quotient max-width))))
  (let n-rows (max 1 ((+ strings.count n-cols -1) .quotient n-cols)))
  (let padded (chain strings
                     ('("") .repeat (- (* n-rows n-cols) strings.count))))
  (transpose (for each ((i (range<- 0 strings.count n-rows))) ;XXX
               (padded .slice i (+ i n-rows)))))

(export format-table tabulate)