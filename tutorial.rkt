#lang racket
(require redex)
(require "subst.rkt")
(provide (all-defined-out))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generic utilities

(define-language REDEX)

(define-judgment-form REDEX
  #:mode (lookup-Σ I I O)
  #:contract (lookup-Σ any_r any_k any_v)
  [(lookup-Σ any_r any_k any_v)
   (where (_ ... any_v _ ...)
	  ,(set->list
	    (hash-ref (term any_r)
		      (term any_k))))])

(define-metafunction REDEX
  ext-Σ1 : any (any any) -> any
  [(ext-Σ1 any_r (any_k any_v))
   ,(hash-set (term any_r)
	      (term any_k)
	      (set-add (hash-ref (term any_r) (term any_k) (set))
		       (term any_v)))])

(define-term Σ∅ ,(hash))

(define-metafunction REDEX
  ext-Σ : any (any any) ... -> any
  [(ext-Σ any_r) any_r]
  [(ext-Σ any_r any_kv0 any_kv1 ...)
   (ext-Σ (ext-Σ1 any_r any_kv0) any_kv1 ...)])


(define-judgment-form REDEX
  #:mode (lookup I I O)
  #:contract (lookup ((any any) ...) any any)
  [(lookup (_ ... (any any_0) _ ...) any any_0)])

(test-equal #t (judgment-holds (lookup ((x 1) (y 2) (x 3)) x 1)))
(test-equal #f (judgment-holds (lookup ((x 1) (y 2) (x 3)) x 2)))
(test-equal #t (judgment-holds (lookup ((x 1) (y 2) (x 3)) x 3)))

(define-judgment-form REDEX
  #:mode (lookup* I I O)
  [(lookup* any_assoc (any_k ...) (any_v ...))
   (lookup any_assoc any_k any_v)
   ...])

(define-metafunction REDEX
  ext : ((any any) ...) (any any) ... -> ((any any) ...)
  [(ext any) any]
  [(ext any any_0 any_1 ...)
   (ext1 (ext any any_1 ...) any_0)])

(define-metafunction REDEX
  ext1 : ((any any) ...) (any any) -> ((any any) ...)
  [(ext1 (any_0 ... (any_k any_v0) any_1 ...) (any_k any_v1))
   (any_0 ... (any_k any_v1) any_1 ...)]
  [(ext1 (any_0 ...) (any_k any_v1))
   ((any_k any_v1) any_0 ...)])

(define-relation REDEX
  unique ⊆ any × ...
  [(unique any_!_1 ...)])

(test-equal #t (term (unique)))
(test-equal #t (term (unique 1)))
(test-equal #f (term (unique 1 2 3 2)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Syntax

(define-language PCF
  (M ::=
     N O X L
     (μ (X : T) L)
     (M M ...)
     (if0 M M M))
  (X ::= variable-not-otherwise-mentioned)
  (L ::= (λ ([X : T] ...) M))
  (V ::= N O L)
  (N ::= number)
  (O ::= O1 O2)
  (O1 ::= add1 sub1)
  (O2 ::= + *)
  (T ::= num (T ... -> T)))


(define-term fact-5
  ((μ (fact : (num -> num))
      (λ ([n : num])
	(if0 n
	     1
	     (* n (fact (sub1 n))))))
   5))

(test-equal (redex-match? PCF M (term fact-5)) true)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reduction semantics

(define r
  (reduction-relation
   PCF #:domain M
   (--> (μ (X : T) M)
	(subst (X (μ (X : T) M)) M)
	μ)

   (--> ((λ ([X : T] ...) M_0) M ...)
	(subst (X M) ... M_0)
	β)

   (--> (O N ...) N_1
	(judgment-holds (δ (O N ...) N_1))
	δ)

   (--> (if0 0 M_1 M_2) M_1 if-t)
   (--> (if0 N M_1 M_2) M_2
	(side-condition (not (equal? 0 (term N))))
	if-f)))

(define -->r
  (compatible-closure r PCF M))

(define-judgment-form PCF
  #:mode (δ I O)
  #:contract (δ (O N ...) N)
  [(δ (+ N_0 N_1) ,(+ (term N_0) (term N_1)))]
  [(δ (* N_0 N_1) ,(* (term N_0) (term N_1)))]
  [(δ (sub1 N) ,(sub1 (term N)))]
  [(δ (add1 N) ,(add1 (term N)))])

(test-->>∃ -->r (term fact-5) 120)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Typing relation

(define-extended-language PCFT PCF
  (Γ ::= ((X T) ...)))

(define-judgment-form PCFT
  #:mode (⊢ I I I O)
  #:contract (⊢ Γ M : T)

  [(lookup Γ X T)
   -------------- var
   (⊢ Γ X : T)]

  [------------- num
   (⊢ Γ N : num)]

  [----------------------- op1
   (⊢ Γ O1 : (num -> num))]

  [--------------------------- op2
   (⊢ Γ O2 : (num num -> num))]

  [(⊢ Γ M_1 : num)
   (⊢ Γ M_2 : T)
   (⊢ Γ M_3 : T)
   --------------------------- if0
   (⊢ Γ (if0 M_1 M_2 M_3) : T)]

  [(⊢ (ext Γ (X T)) L : T)
   ----------------------- μ
   (⊢ Γ (μ (X : T) L) : T)]

  [(⊢ Γ M_0 : (T_1 ..._1 -> T))
   (⊢ Γ M_1 : T_1) ...
   ----------------------- app
   (⊢ Γ (M_0 M_1 ..._1) : T)]

  [(unique X ...)
   (⊢ (ext Γ (X T) ...) M : T_n)
   ------------------------------------------ λ
   (⊢ Γ (λ ([X : T] ...) M) : (T ... -> T_n))])

(test-equal (judgment-holds (⊢ () fact-5 : T) T)
	    (term (num)))

(test-equal (judgment-holds (⊢ () (λ ([x : num] [x : num]) x) : T) T)
	    (term ()))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Evaluation relation

(define-extended-language PCF⇓ PCF
  (V ::= N O (L ρ) ((μ (X : T) L) ρ))
  (ρ ::= ((X V) ...)))

(define-judgment-form PCF⇓
  #:mode (⇓ I I I O)
  #:contract (⇓ M ρ : V)

  [(⇓ N ρ : N)]
  [(⇓ O ρ : O)]
  [(⇓ L ρ : (L ρ))]
  [(⇓ (μ (X_f : T_f) L) ρ : ((μ (X_f : T_f) L) ρ))]

  [(lookup ρ X V)
   --------------
   (⇓ X ρ : V)]

  [(⇓ M_0 ρ : N)
   (where M ,(if (zero? (term N)) (term M_1) (term M_2)))
   (⇓ M ρ : V)
   ---------------------------
   (⇓ (if0 M_0 M_1 M_2) ρ : V)]

  [(⇓ M_0 ρ : O)
   (⇓ M_1 ρ : N)
   ...
   (δ (O N ...) N_1)
   -----------------------
   (⇓ (M_0 M_1 ...) ρ : N_1)]

  [(⇓ M_0 ρ : ((λ ([X_1 : T] ...) M) ρ_1))
   (⇓ M_1 ρ : V_1)
   ...
   (⇓ M (ext ρ_1 (X_1 V_1) ...) : V)
   -----------------------------------
   (⇓ (M_0 M_1 ...) ρ : V)]

  [(⇓ M_0 ρ : (name f ((μ (X_f : T_f) (λ ([X_1 : T] ...) M)) ρ_1)))
   (⇓ M_1 ρ : V_1)
   ...
   (⇓ M (ext ρ_1 (X_f f) (X_1 V_1) ...) : V)
   -----------------------------------------
   (⇓ (M_0 M_1 ...) ρ : V)])

(test-equal (judgment-holds (⇓ fact-5 () : V) V) (term (120)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Call-by-value PCF reduction semantics

(define-extended-language PCFn PCF
  (E ::= hole
     (E M ...)
     (O V ... E M ...)
     (if0 E M M)))

(define -->n
  (context-closure r PCFn E))

(test-->> -->n (term fact-5) 120)

(define-extended-language PCFv PCF
  (E ::= hole
     (V ... E M ...)
     (if0 E M M)))

(define v
  (extend-reduction-relation
   r PCF #:domain M
   (--> ((λ ([X : T] ...) M_0) V ...)
	(subst (X V) ... M_0)
	β)))

(define -->v
  (context-closure v PCFv E))

(test-->> -->v (term fact-5) 120)

(define-term Ω
  ((μ (loop : (num -> num))
      (λ ([x : num])
	(loop x)))
   0))

(test-->> -->n (term ((λ ([x : num]) 0) Ω)) 0)
(test-->> -->v #:cycles-ok (term ((λ ([x : num]) 0) Ω)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Explicit substitution reduction semantics

(define-extended-language PCFρ PCF⇓
  (C ::= V (M ρ) (if0 C C C) (C C ...))
  (E ::= hole (V ... E C ...) (if0 E C C)))

(define vρ
  (reduction-relation
   PCFρ #:domain C
   (--> ((if0 M ...) ρ) (if0 (M ρ) ...) ρ-if)
   (--> ((M ...) ρ) ((M ρ) ...) ρ-app)
   (--> (O ρ) O ρ-op)
   (--> (N ρ) N ρ-num)
   (--> (X ρ) V
	(judgment-holds (lookup ρ X V))
	ρ-x)

   (--> (((λ ([X : T] ...) M) ρ) V ...)
	(M (ext ρ (X V) ...))
	β)

   (--> ((name f ((μ (X_f : T_f) (λ ([X : T] ...) M)) ρ)) V ...)
	(M (ext ρ (X_f f) (X V) ...))
	rec-β)

   (--> (O V ...) V_1
	(judgment-holds (δ (O V ...) V_1))
	δ)

   (--> (if0 0 C_1 C_2) C_1 if-t)
   (--> (if0 N C_1 C_2) C_2
	(side-condition (not (equal? 0 (term N))))
	if-f)))

(define -->vρ
  (context-closure vρ PCFρ E))

(define-metafunction PCFρ
  injρ : M -> C
  [(injρ M) (M ())])

(test-->> -->vρ (term (injρ fact-5)) 120)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Eval/Continue/Appy machine

(define-extended-language PCFς PCFρ
  (F ::= (V ... [] C ...) (if0 [] C C))
  (K ::= (F ...))
  (S ::= ; serious terms S ∩ V = ∅, C = S ∪ V
     (N ρ)
     (O ρ)
     (X ρ)
     ((M M ...) ρ)
     ((if0 M M M) ρ)
     (if0 C C C)
     (C C ...))
  (ς ::= (C K) V))

(define -->vς
  (extend-reduction-relation
   ;; Apply
   (context-closure vρ PCFς (hole K))
   PCFς
   ;; Eval
   (--> ((if0 S_0 C_1 C_2) (F ...))
	(S_0 ((if0 [] C_1 C_2) F ...))
	ev-if)

   (--> ((V ... S C ...) (F ...))
	(S ((V ... [] C ...) F ...))
	ev-app)

   ;; Continue
   (--> (V ()) V halt)

   (--> (V ((if0 [] C_1 C_2) F ...))
	((if0 V C_1 C_2) (F ...))
	co-if)

   (--> (V ((V_0 ... [] C_0 ...) F ...))
	((V_0 ... V C_0 ...) (F ...))
	co-app)))

(define-metafunction PCFς
  injς : M -> ς
  [(injς M) ((injρ M) ())])

(test-->> -->vς (term (injς fact-5)) 120)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Relating -->vς and -->vρ

(define-metafunction PCFς
  K->E : K -> E
  [(K->E ()) hole]
  [(K->E ((if0 [] C_0 C_1) F ...))
   (in-hole (K->E (F ...)) (if0 hole C_0 C_1))]
  [(K->E ((V ... [] C ...) F ...))
   (in-hole (K->E (F ...)) (V ... hole C ...))])

(define-metafunction PCFς
  E->K : E -> K
  [(E->K hole) ()]
  [(E->K (if0 E C_0 C_1))
   (F ... (if0 [] C_0 C_1))
   (where (F ...) (E->K E))]
  [(E->K (V ... E C ...))
   (F ... (V ... [] C ...))
   (where (F ...) (E->K E))])

;(redex-check PCFς E (equal? (term E) (term (K->E (E->K E)))))
;(redex-check PCFς K (equal? (term K) (term (E->K (K->E K)))))

(define-relation PCFς
  ≈ςρ ⊆ ς × C
  [(≈ςρ V V)]
  [(≈ςρ (C_0 K) C_1)
   (where C_1 (in-hole (K->E K) C_0))])

;; If (≈ςρ ς C), then either:
;; - ς = C = V for some V,
;; - ς -->vς ς′ by an eval, continute, or halt transition
;;   and (≈ςρ ς′ C)
;; - ς -->vς ς′ by an apply transition,
;;   C -->vρ C′, and (≈ςρ ς′ C′)

;; Check above claim holds at each step of reduction
(define-metafunction PCFς
  inv : ς C -> boolean
  [(inv V C) (≈ςρ V C)]
  ;; ς -->vς ς′ by eval, continue, or halt.
  [(inv ς C)
   (inv ς_1 C)
   (where #t (≈ςρ ς C))
   (where ((any_rule ς_1))
	  ,(apply-reduction-relation/tag-with-names -->vς (term ς)))
   (where (_ ... any_rule _ ...)
	  ("ev-if" "ev-app" "co-if" "co-app" "halt"))]
  ;; ς -->vς ς′ by apply transition.
  [(inv ς C)
   (inv ς_1 C_1)
   (where #t (≈ςρ ς C))
   (where (ς_1)
	  ,(apply-reduction-relation -->vς (term ς)))
   (where (C_1)
	  ,(apply-reduction-relation -->vρ (term C)))]
  [(inv ς C) #f])

(test-equal #t (term (inv (injς fact-5) (injρ fact-5))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Eval/Continue/Apply machine with heap

(define-extended-language PCFσ PCFς
  (ρ ::= .... ((X A) ...))
  (Σ ::= ((A V) ...))
  (A ::= any)
  (σ ::= (ς Σ) V))

(define-syntax-rule (-->vσ/Σ alloc ext-Σ lookup-Σ)
  (...
   (extend-reduction-relation
    (context-closure -->vς PCFσ (hole Σ))
    PCFσ
    (--> (N Σ) N discard-Σ)
    (--> (((X ρ) K) Σ) ((V K) Σ)
	 (judgment-holds (lookup ρ X A))
	 (judgment-holds (lookup-Σ Σ A V))
	 ρ-x)

    (--> (name σ (((((λ ([X : T] ...) M) ρ) V ...) K) Σ))
	 (((M (ext ρ (X A) ...)) K) (ext-Σ Σ (A V) ...))
	 (where (A ...) (alloc σ))
	 β)

    (--> (name σ ((((name f ((μ (X_f : T_f) (λ ([X : T] ...) M)) ρ)) V ...) K) Σ))
	 (((M (ext ρ (X_f A_f) (X A) ...)) K) (ext-Σ Σ (A_f f) (A V) ...))
	 (where (A_f A ...) (alloc σ))
	 rec-β))))

(define-syntax-rule
  (-->vσ/alloc alloc)
  (-->vσ/Σ alloc ext lookup))

(define-metafunction PCFσ
  formals : M -> (X ...)
  [(formals (λ ([X : T] ...) M)) (X ...)]
  [(formals (μ (X_f : T_f) L)) (X_f X ...)
   (where (X ...) (formals L))])

(define-metafunction PCFσ
  alloc : ((C K) Σ) -> (A ...)
  [(alloc ((((M ρ) V ...) K) Σ))
   ,(map (λ (x) (list x (gensym x)))
	 (term (formals M)))])

(define -->vσ (-->vσ/alloc alloc))

(define-metafunction PCFσ
  injσ : M -> σ
  [(injσ M) ((injς M) ())])

(test-->> -->vσ (term (injσ fact-5)) 120)

(define-metafunction PCFσ
  alloc-gensym : ((C K) Σ) -> (A ...)
  [(alloc-gensym ((((M ρ) V ...) K) Σ))
   ,(map gensym (term (formals M)))])

(define-metafunction PCFσ
  alloc-nat : ((C K) Σ) -> (A ...)
  [(alloc-nat ((((M ρ) V ...) K) ((A _) ...)))
   ,(let ((n (add1 (apply max 0 (term (A ...))))))
      (build-list (length (term (formals M)))
		  (λ (i) (+ i n))))])

(test-->> (-->vσ/alloc alloc-gensym)
	  (term (injσ fact-5))
	  120)

(test-->> (-->vσ/alloc alloc-nat)
	  (term (injσ fact-5))
	  120)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Relating -->vσ and -->vς

(define-relation PCFσ
  ≈σς ⊆ σ × ς
  [(≈σς σ ς)
   (where ς (σ->ς σ))])

(define-metafunction PCFσ
  σ->ς : σ -> ς
  [(σ->ς V) V]
  [(σ->ς (V Σ))
   (CΣ->C V Σ)]
  [(σ->ς ((C K) Σ))
   ((CΣ->C C Σ) (KΣ->K K Σ))])

(define-metafunction PCFσ
  ρΣ->ρ : ρ Σ -> ρ
  [(ρΣ->ρ ((X V) ...) Σ) ((X V) ...)]
  [(ρΣ->ρ ((X A) ...) Σ)
   ((X V) ...)
   (judgment-holds (lookup* Σ (A ...) (V ...)))])

(define-metafunction PCFσ
  CΣ->C : C Σ -> C
  [(CΣ->C N Σ) N]
  [(CΣ->C O Σ) O]
  [(CΣ->C (M ρ) Σ) (M (ρΣ->ρ ρ Σ))]
  [(CΣ->C (if0 C ...) Σ) (if0 (CΣ->C C Σ) ...)]
  [(CΣ->C (C ...) Σ) ((CΣ->C C Σ) ...)])

(define-metafunction PCFσ
  KΣ->K : K Σ -> K
  [(KΣ->K (F ...) Σ)
   ((FΣ->F F Σ) ...)])

(define-metafunction PCFσ
  FΣ->F : F Σ -> F
  [(FΣ->F (if0 [] C_1 C_2) Σ)
   (if0 [] (CΣ->C C_1 Σ) (CΣ->C C_2 Σ))]
  [(FΣ->F (V ... [] C ...) Σ)
   ((CΣ->C V Σ) ... [] (CΣ->C C Σ) ...)])


;; If (≈σς σ ς), then either:
;; - if σ = (V Σ) then ς = V′ and (≈σς (V Σ) V′),
;; - if σ -->vσ σ′ then
;;   ς -->vς ς′, and (≈ςρ σ′ ς′)

;; Check above claim holds at each step of reduction
(define-metafunction PCFσ
  inv-σς : σ ς -> boolean
  [(inv-σς (V Σ) V_1)
   (≈σς (V Σ) V_1)]
  ;; ς -->vσ ς′
  [(inv-σς σ ς)
   (inv-σς σ_1 ς_1)
   (where #t (≈σς σ ς))
   (where (σ_1) ,(apply-reduction-relation -->vσ (term σ)))
   (where (ς_1) ,(apply-reduction-relation -->vς (term ς)))]
  [(inv-σς σ ς) #f])


(test-equal #t (term (inv-σς (injσ fact-5) (injς fact-5))))

;; This diverges
#;
(test-equal #t
	    (term (inv-σς (injσ Ω)
			  (injς Ω))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Heap allocated continuations

(define-extended-language PCFσ* PCFσ
  (K ::= () (F A))
  (Σ ::= ((A U) ...))
  (U ::= V K))

(define-metafunction/extension alloc PCFσ*
  alloc* : ((C K) Σ) -> (A ...)
  [(alloc* (((if0 S_0 C_1 C_2) K) Σ))
   (((if0 [] C_1 C_2) ,(gensym 'if0)))]
  [(alloc* (((V ... S C ...) K) Σ))
   (((V ... [] C ...) ,(gensym 'app)))])


(define-syntax-rule
  (-->vσ*/Σ alloc* ext-Σ lookup-Σ)
  (...
   (extend-reduction-relation
    (-->vσ/Σ alloc* ext-Σ lookup-Σ)
    PCFσ*
    ;; Eval
    (--> (name σ (((if0 S_0 C_1 C_2) K) Σ))
	 ((S_0 ((if0 [] C_1 C_2) A)) (ext-Σ Σ (A K)))
	 (where (A) (alloc* σ))
	 ev-if)

    (--> (name σ (((V ... S C ...) K) Σ))
	 ((S ((V ... [] C ...) A)) (ext-Σ Σ (A K)))
	 (where (A) (alloc* σ))
	 ev-app)

    ;; Continue
    (--> ((V ((if0 [] C_1 C_2) A)) Σ)
	 (((if0 V C_1 C_2) K) Σ)
	 (judgment-holds (lookup-Σ Σ A K))
	 co-if)

    (--> ((V ((V_0 ... [] C_0 ...) A)) Σ)
	 (((V_0 ... V C_0 ...) K) Σ)
	 (judgment-holds (lookup-Σ Σ A K))
	 co-app))))

(define-syntax-rule
  (-->vσ*/alloc alloc*)
  (-->vσ*/Σ alloc* ext lookup))

(define -->vσ* (-->vσ*/alloc alloc*))

(test-->> -->vσ* (term (injσ fact-5)) 120)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set-based heap

(define-extended-language PCFσ∘ PCFσ*
  (Σ ::= any))

(define-syntax-rule (-->vσ∘/Σ alloc ext-Σ lookup-Σ)
  (extend-reduction-relation
   (-->vσ*/Σ alloc ext-Σ lookup-Σ)
   PCFσ∘))

(define-metafunction/extension alloc* PCFσ∘
  alloc∘ : σ -> (A ...))

(define -->vσ∘ (-->vσ∘/Σ alloc∘ ext-Σ lookup-Σ))

(define-metafunction PCFσ∘
  injσ∘ : M -> σ
  [(injσ∘ M) ((injς M) Σ∅)])

(test-->> -->vσ∘ (term (injσ∘ fact-5)) 120)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; AAM

(define-extended-language PCFσ^ PCFσ∘
  (N ::= .... num))

(define-judgment-form PCFσ^
  #:mode (δ^ I O)
  #:contract (δ^ (O N ...) N)
  [(δ^ (O N_0 N_1) num)]
  [(δ^ (O N) num)])

(define-metafunction/extension alloc∘ PCFσ^
  alloc∘^ : ((C K) Σ) -> (A ...))

(define-metafunction PCFσ^
  alloc^ : ((C K) Σ) -> (A ...)
  [(alloc^ σ)
   (A ...)
   (where ((A _) ...) (alloc∘^ σ))])

(define -->vσ^
  (extend-reduction-relation
   (-->vσ∘/Σ alloc^ ext-Σ lookup-Σ)
   PCFσ^

   ;; BUG WORKAROUND: ρ-x, co-if, & co-app
   ;; repeated here to work around
   ;; http://bugs.racket-lang.org/query/?cmd=view&pr=14660
   (--> (((X ρ) K) Σ) ((V K) Σ)
	(judgment-holds (lookup ρ X A))
	(judgment-holds (lookup-Σ Σ A V))
	ρ-x)
   ;; Continue
   (--> ((V ((if0 [] C_1 C_2) A)) Σ)
	(((if0 V C_1 C_2) K) Σ)
	(judgment-holds (lookup-Σ Σ A K))
	co-if)

   (--> ((V ((V_0 ... [] C_0 ...) A)) Σ)
	(((V_0 ... V C_0 ...) K) Σ)
	(judgment-holds (lookup-Σ Σ A K))
	co-app)

   (--> (((O N ...) K) Σ)
	((N_1 K) Σ)
	(judgment-holds (δ^ (O N ...) N_1))
	δ)
   (--> (((if0 num C_1 C_2) K) Σ)
	((C_1 K) Σ)
	if0-num-t)
   (--> (((if0 num C_1 C_2) K) Σ)
	((C_2 K) Σ)
	if0-num-f)))


(current-cache-all? #t)
(apply-reduction-relation* -->vσ^ (term (injσ∘ fact-5)))
(test-->> -->vσ^ (term (injσ∘ fact-5)) 1 'num)

;(define -->vσ*^ (-->vσ*^/alloc alloc*^))


(test-->> -->vσ^
	  (term (injσ∘ ((λ ([f : (num -> num)])
			  ((λ ([_ : num]) (f 0)) (f 1)))
			(λ ([z : num]) z))))
	  0 1)

(define-term dead-code
  ((λ ([f : (num -> num)])
     ((λ ([_ : num]) (f 0)) (f 1)))
   (λ ([z : num]) Ω)))


#;
(traces
 -->vσ^
 (term (injσ∘ ((λ ([f : (num -> num)])
		 ((λ ([_ : num]) (f 0)) (f 1)))
	       (λ ([z : num]) Ω)))))


(define (step r ts)
  (list->set (for/fold ([a '()])
	       ([t (in-set ts)])
	       (append (apply-reduction-relation r t) a))))

(define (reach r t)
  (let loop ([accum (set)]
	     [front (set t)])
    (if (set-empty? front)
	accum
	(let ([n (step r front)])
	  (loop (set-union accum front)
		(set-subtract n accum))))))

(define (reach-filter r t pred)
  (for/set ([t (in-set (reach r t))]
	    #:when (pred t))
    t))

(define (irreducible r t)
  (reach-filter r t
    (λ (t) (empty? (apply-reduction-relation r t)))))


#|
(apply-reduction-relation* -->vσ^ (term (injσ∘ Ω)))

(apply-reduction-relation*
 -->vσ^
 (term (injσ∘ (if0 (add1 5) 2 3))))

(apply-reduction-relation*
 -->vσ^
 (term (injσ∘ ((μ (f : (num -> num))
		  (λ ([z : num])
		    (if0 z
			 0
			 (f (sub1 z)))))
	       10))))
|#



;(apply-reduction-relation* -->vσ^ (term (injσ∘ fact-5)))


#;
(test-->> -->vσ*^ (term (injσ (if0 (add1 0) 1 2)))
	  1 2)

#|
(define -->vσ*^
  (extend-reduction-relation
   (-->vσ*/alloc alloc*)
   PCFσ*^
  |#