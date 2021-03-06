(to (legal-register? x size)
  ((possible-registers size) .find? x))

;; The general registers by size, and then by their 3-bit code.
(let possible-registers
  (map<-
   '((1 #(%al %cl %dl %bl %ah %ch %dh %bh))
     (2 #(%ax %cx %dx %bx %sp %bp %si %di))
     (4 #(%eax %ecx %edx %ebx %esp %ebp %esi %edi)))))

;; TODO instead of a symbol and lookup, consider creating register
;; objects which know their number.
(let register-number
  (map<-
   '((%es 0) (%cs 1) (%ss 2) (%ds 3) (%fs 4) (%gs 5)
     (%cr0 0) (%cr2 2) (%cr3 3) (%cr4 4)
     (%dr0 0) (%dr1 1) (%dr2 2) (%dr3 3) (%dr6 6) (%dr7 7))))

(for each! ((registers possible-registers.values))
  ;; TODO use an .update! method
  (for each! ((`(,num ,name) registers.items))
    (surely (not (register-number .maps? name)))
    (register-number .set! name num)))

;; The set of all registers that can appear as instruction arguments.
(let registers (call set<- register-number.keys))
;; TODO the .keys should be a kind of set already

(to (register? x)
  (registers .maps? x))

(export possible-registers register-number registers register?)
