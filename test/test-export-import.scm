;; Try out sugar for import and export.

(hide

 (let a-module
   (hide
    (let f 'howdy)
    (let g 'doody)
    (let a (export f g))
    (print a)
    (print (a 'g))
    (print (a 'f))
    a))

 (import a-module f g)
 (display "f and g") (newline)
 (print f)
 (print g)
)
