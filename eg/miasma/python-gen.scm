(import (use "eg/miasma/registers") registers register-number)
(import (use "eg/miasma/parse") the-specs setup-spec-table)
(import (use "eg/miasma/walk") walk-code walk-exp unit bind swapping eating)

(to (main _)
  (setup-spec-table)
  (generate-py-assembler "asm.py"))

(to (generate-py-assembler filename)
  (with-output-file py-write-assembler filename))

(to (say-to sink @arguments)
  (for each! ((x arguments))
    (sink .display x))
  (sink .display "\n"))

(to (copy-file source sink)
  (sink .display source.read-all))

(to (py-write-assembler sink)
  (say-to sink "# Generated by Miasma")
  (say-to sink)
  (for with-input-file ((source "eg/miasma/python/x86_stub.py"))
    (copy-file source sink))
  (say-to sink)
  (say-to sink (py-enum registers.keys (each register-number registers.keys)))
  (say-to sink)
  (for each! ((spec the-specs.values))
    (say-to sink (py-gen spec.mnemonic spec.params))))


;; Code translation

(to (py-gen mnemonic code-list)
  (let vars (py-make-variable-list 
             (foldl + 0 (each py-variable-count code-list))))
  (py-stmt-macro (py-insn-name mnemonic)
                 vars
                 (py-body vars code-list)))

(to (py-make-variable-list n)
  (for each ((k (range<- 1 (+ n 1))))
    ("v~w" .format k)))

(to (py-body vars code-list)
  (begin walking ((code-list code-list) (stmts '()))
    (match code-list
      (`() stmts)
      (`(,first ,@rest)
       ((walk-code first py-code py-exp) vars
                                         (given (vars cv) 
                                           (walking rest `(,cv ,@stmts))))))))

;; TODO walker objects instead, with code/exp methods?

(to (py-code code)
  (match code
    ({bytes signed? count exp}
     (for bind ((cv exp))
       (unit 
        (py-exp-stmt (py-call ("push_~d~w" .format (if signed? "i" "u")
                                                   (* 8 count))
                              cv)))))
    ({swap-args code}
     (swapping code))
    ({mod-r/m e1 e2}
     (for bind ((cv1 e1))
       (for bind ((cv2 e2))
         (unit (py-exp-stmt (py-call "mod_rm" cv1 cv2))))))))

(to (py-exp exp)
  (match exp
    ({literal n}
     (unit (py-int-literal n)))
    ({op operator e1 e2}
     (for bind ((cv1 e1))
       (for bind ((cv2 e2))
         (unit (py-binop operator.name cv1 cv2)))))
    ({hereafter}
     (unit "hereafter"))
    ({arg @_}
     (eating unit))))


;; Variables

(to (py-variable-count code)

  (to (py-code code)
    (match code
      ({bytes _ _ exp}
       exp)
      ({swap-args code}
       code)
      ({mod-r/m e1 e2}
       (for bind ((cv1 e1))
         (for bind ((cv2 e2))
           (unit (+ cv1 cv2)))))))

  (to (py-exp exp)
    (match exp
      ({literal _}
       (unit 0))
      ({op operator e1 e2}
       (for bind ((cv1 e1))
         (for bind ((cv2 e2))
           (unit (+ cv1 cv2)))))
      ({hereafter}
       (unit 0))
      ({arg @_}
       (unit 1))))

  ((walk-code code py-code py-exp) '_
                                   (given (_ count) count)))


;; Python code constructors

(to (py-enum symbols values)
  ("\n" .join (for each ((`(,sym ,val) (zip symbols values)))
                (chain (as-legal-py-identifier sym.name)
                       " = "
                       (py-int-literal val)))))

(to (py-int-literal n)
  (if (and (<= 0 n) (integer? n))
      ("0x~d" .format (string<-number n 16)) ;TODO ~h format or something
      (string<-number n)))

(to (py-binop operator cv1 cv2)
  ("(~d ~d ~d)" .format cv1 operator cv2))

(to (py-parenthesize cv)
  (chain "(" cv ")"))

(to (py-call fn-cv @args-cv)
  ("~d(~d)" .format fn-cv (", " .join args-cv)))

(to (py-exp-stmt cv)
  cv)

(to (py-stmt-macro name vars stmts)
  ("\n" .join `(,(py-declare name vars) 
                "    global buf"
                "    hereafter = len(buf)"
                ,@(for each ((stmt stmts))
                    (chain "    " stmt)))))

(to (py-declare name vars)
  ("def ~d(~d):" .format name (", " .join vars)))

(to (py-insn-name mnemonic)
  (as-legal-py-identifier mnemonic.name))

;; Return `str`, but munging out any characters that are used in our 
;; mnemonics but aren't legal in Python identifiers.
(to (as-legal-py-identifier str)
  (string<-list (for filter ((ch str))
                  (and (not (":%" .find? ch))
                       (case (("-." .find? ch) #\_)
                             ((= #\? ch) #\c)
                             (else ch))))))
