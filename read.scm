;; Adapted from my UTS Scheme reader.
;; This relies on char->integer returning a number in [0..255].

;; Conventions:
;;   port   an input port
;;   c      a character (or possibly an EOF object)

;; XXX error reporting could be a lot better

(define (skip-blanks port)
  (let loop ()
    (let ((c (peek-char port)))
      (cond ((eof-object? c))
	    ((char-whitespace? c)
	     (read-char port)
	     (loop))
	    ((char=? c #\;)
	     (flush-input-line port)
	     (loop))))))

(define (read-atom port c)

  (define (symbol-terminator? c)
    (or (eof-object? c)
	(char-whitespace? c)
	(memv c '(#\( #\) #\; #\" #\` #\, #\@ #\{ #\}))))

  (define (atomize L len)
    (let ((s (make-string len #\space)))
      (let walk ((i (- len 1)) (L L))
        (if (< i 0)
            (or (string->number s)
                (string->symbol s))
            (begin (string-set! s i (car L))
                   (walk (- i 1) (cdr L)))))))

  (define (combine prefix atom)
    (cond (prefix
           (if (not (symbol? atom))
               (error "Floating-point literals unimplemented" prefix atom))
           (list prefix (cue<- atom)))
          (else
           atom)))

  (let loop ((prefix #f) (L (list c)) (len 1))
    (let ((c (peek-char port)))
      (cond ((eq? c #\.)
             (let ((prefix (combine prefix (atomize L len))))
               (read-char port)
               (let ((c (peek-char port)))
                 (if (not (symbol-constituent? c))
                     (error "Symbol ending in '.'"))
                 (loop prefix (list (read-char port)) 1))))
            ((symbol-terminator? c)
             (combine prefix (atomize L len)))
            (else
             (loop prefix (cons (read-char port) L) (+ len 1)))))))

(define (symbol-constituent? c)
  (or (char-alphabetic? c)
      (char-numeric? c)
      (memv c '(#\! #\$ #\% #\^ #\& #\* #\/ #\? #\= #\+ #\- #\_ #\< #\>))))

(define (flush-input-line port)
  (let loop ()
    (let ((c (read-char port)))
      (cond ((eof-object? c))
	    ((char=? c #\newline))
	    (else (loop))))))

(define (optional-arg arg-list default-value)
  (cond ((null? arg-list) default-value)
        ((null? (cdr arg-list)) (car arg-list))
        (else (error "Too many arguments to procedure" arg-list))))

(define squeam-read
  (let ()

    (define read-error error)

    (define (unknown-char port c)
      (read-error "Unknown read syntax" c))

    (define the-readtable (make-vector 128 unknown-char))

    (define (install-read-macro c reader)
      (vector-set! the-readtable (char->integer c) reader))

    (define (read port)
      (let ((c (read-char port)))
	(if (eof-object? c)
	    c
	    ((vector-ref the-readtable (char->integer c)) 
	     port 
	     c))))

    (define (must-read port)
      (let ((result (read port)))
        (if (eof-object? result)
            (read-error "Unexpected EOF"))
        result))

    ;; list ::= '(' expr* ')'
    (define (read-list port c)
      (read-seq #\) port c))

    (define (read-seq close-paren port c)
      (let reading ()
        (skip-blanks port)
        (let ((c (peek-char port)))
          (cond ((eof-object? c) 
                 (read-error port "Unexpected EOF before" close-paren))
                ((char=? c close-paren)
                 (read-char port)
                 '())
                (else
                 (cons (must-read port) (reading)))))))

    (define (read-term port c)
      (term<-list (read-seq #\} port c)))


    ;; White space
    (let initializing ((i 33))
      (cond ((< i 127)
             (if (symbol-constituent? (integer->char i))
                 (vector-set! the-readtable i read-atom))
             (initializing (+ i 1)))))

    (for-each 
     (lambda (white) 
       (install-read-macro white 
	 (lambda (port c) 
	   (skip-blanks port)
	   (read port))))
     '(#\space #\tab #\newline #\return))

    (install-read-macro #\;
      (lambda (port c)
	(flush-input-line port)
	(read port)))

    (install-read-macro #\( read-list)

    (install-read-macro #\)
      (lambda (port c)
	(read-error port "Unbalanced parentheses")))

    (install-read-macro #\{ read-term)

    (install-read-macro #\}
      (lambda (port c)
	(read-error port "Unbalanced {}")))

    (install-read-macro #\.
      (lambda (port c)
        (skip-blanks port)
        (let ((c (peek-char port)))
          (if (symbol-constituent? c)
              (let ((atom (read-atom port (read-char port))))
                (cond ((number? atom)
                       (read-error "Floating-point literals unimplemented"))
                      ((symbol? atom)
                       (cue<- atom))
                      (else
                       (read-error "Bad syntax after '.'" atom))))
              (read-error "Lone '.'")))))

    (install-read-macro #\#
      (lambda (port c)
        ;; TODO: add back a syntax for non-decimal numbers
        (let ((next (read-char port)))
          (case next
            ((#\\)
             (let ((next (read-char port)))
               (if (and (char-alphabetic? next)
                        (char-alphabetic? (peek-char port)))
                   (let ((symbol (read-atom port next)))
                     (let ((table '(; (backspace . #\backspace)
				    ; (escape . #\escape)
				    ; (page . #\page)
                                    (newline . #\newline)
                                    (return . #\return)
                                    (space . #\space)
                                    (tab . #\tab)
                                    )))
                       (let ((pair (assq symbol table)))
                         (if (pair? pair)
                             (cdr pair)
                             (read-error port 
                                         "Unknown character constant - #\\"
                                         symbol)))))
                   next)))
            (( #\( )	; vector constant
             (list->vector (read-list port next)))
            (else
             (cond ((char-alphabetic? next)
                    (let ((sym (read-atom port next)))
                      (case sym
                        ((yes) #t)
                        ((no) #f)
                        (else
                         (read-error port "Unknown '#' read macro" sym)))))
                   (else
                    (read-error port "Unknown '#' read macro" next))))))))

    (install-read-macro #\"
      (lambda (port c)
	(let loop ((prev-chars '()))
	  (let ((c (read-char port)))
	    (cond
	     ((eof-object? c)
	      (read-error port "Unexpected EOF in string constant"))
	     ((char=? c #\")
	      (list->string (reverse prev-chars)))
	     ((char=? c #\\)
	      (let ((c (read-char port)))
		(cond
		 ((eof-object? c)
		  (read-error port "Unexpected EOF in escape sequence"))
		 ((assv c '((#\\ . #\\)
                            (#\" . #\")
                            (#\n . #\newline)
                            (#\t . #\tab)
                            (#\r . #\return)))
		  => (lambda (pair)
		       (loop (cons (cdr pair) prev-chars))))
		 (else (read-error port 
				   "Unknown escape sequence in string")))))
	     (else (loop (cons c prev-chars))))))))

    (install-read-macro #\'
      (lambda (port c)
	(list 'quote (read port))))
    
    (install-read-macro #\`
      (lambda (port c)
	(list 'quasiquote (read port))))

    (install-read-macro #\,
      (lambda (port c)
	(list 
	 (if (eqv? (peek-char port) #\@)
	     (begin (read-char port) 'unquote-splicing)
	     'unquote)
	 (read port))))

    (lambda opt:in-port
      (read (optional-arg opt:in-port (current-input-port))))))
