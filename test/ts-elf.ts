# -*- coding: utf-8 -*-

# Here we translate the file ../NOTES/ts.elf into our syntax;;

Include "rules/abbreviations.ts";;

Axiom LF Empty_istype : istype Empty;;

Axiom LF ∏_istype : (T1:texp) ⟶ (T2:oexp⟶texp) ⟶
      istype T1 ⟶
      ((x:oexp) ⟶ hastype x T1 ⟶ istype (T2 x)) ⟶
      istype (@Pi T1 T2);;

Axiom LF λ_hastype : (T1:texp) ⟶ (T2:oexp⟶texp) ⟶ (O:oexp⟶oexp) ⟶
      ((x:oexp) ⟶ hastype x T1 ⟶ hastype (O x) (T2 x)) ⟶
      hastype (@lambda T1 O) (@Pi T1 T2);;

Axiom LF ev_hastype : (T1:texp) ⟶ (T2:oexp⟶texp) ⟶ (F:oexp) ⟶ (O:oexp) ⟶
      hastype F (@Pi T1 T2) ⟶ hastype O T1 ⟶ hastype (@ev F O T1 T2) (T2 O);;

Axiom LF empty_r_hastype : (O:oexp) ⟶ (T:texp) ⟶ hastype O Empty ⟶
      istype T ⟶ hastype (@empty_r T O) T;;

Axiom LF eq_hastype : (T1:texp) ⟶ (T2:texp) ⟶ (O:oexp) ⟶ tequal T1 T2 ⟶
      hastype O T2 ⟶ hastype O T1;;

Axiom LF o_eq_beta : (T1:texp) ⟶ (T2:oexp⟶texp) ⟶ (O1:oexp) ⟶ (O2:oexp⟶oexp) ⟶
      (x:oexp) ⟶ hastype x T1 ⟶ hastype (O2 x) (T2 x) ⟶
      hastype O1 T1 ⟶
      oequal (@ev (@lambda T1 O2) O1 T1 T2) (O2 O1) (T2 O1);;

Axiom LF o_eq_app : (T1:texp) ⟶ (T2:oexp⟶texp) ⟶ (O:oexp) ⟶ (O':oexp) ⟶
      (F:oexp) ⟶ (F':oexp) ⟶
      oequal O O' T1 ⟶ oequal F F' (@Pi T1 T2) ⟶
      oequal (@ev F O T1 T2) (@ev F' O' T1 T2) (T2 O);;

Axiom LF o_eq_empty_eta : (O:oexp) ⟶ (O1:oexp) ⟶ (O2:oexp) ⟶ (A:texp) ⟶
      hastype O Empty ⟶ hastype O1 A ⟶ hastype O2 A ⟶ oequal O1 O2 A;;

Axiom LF t_eq_empty_eta : (O:oexp) ⟶ (B:texp) ⟶ (A:texp) ⟶
      hastype O Empty ⟶ istype B ⟶ istype A ⟶ tequal A B;;

Theorem LF foo : (T1:texp) ⟶ (T2:texp) ⟶ (T3:texp) ⟶ (F:oexp) ⟶ (O:oexp) ⟶ (Bad:oexp) ⟶
      istype T1 ⟶ istype T2 ⟶ hastype O T1 ⟶ hastype F (@Pi T2 (_ ⟼ T3)) ⟶
      hastype Bad Empty ⟶ hastype (@ev F O T2 (_ ⟼ T3)) T3
      :=
      T1 ⟼ T2 ⟼ T3 ⟼ F ⟼ O ⟼ Bad ⟼ dT1 ⟼ dT2 ⟼ dO ⟼ dF ⟼ dBad ⟼
      (ev_hastype T2 (_ ⟼ T3) F O dF
      	(eq_hastype T2 T1 O (t_eq_empty_eta Bad T1 T2 dBad dT1 dT2) dO));;

# this time with tactics:
Theorem LF foo' : (T1:texp) ⟶ (T2:texp) ⟶ (T3:texp) ⟶ (F:oexp) ⟶ (O:oexp) ⟶ (Bad:oexp) ⟶
      istype T1 ⟶ istype T2 ⟶ hastype O T1 ⟶ hastype F (@Pi T2 (_ ⟼ T3)) ⟶
      hastype Bad Empty ⟶ hastype (@ev F O T2 (_ ⟼ T3)) T3
      :=
      T1 ⟼ T2 ⟼ T3 ⟼ F ⟼ O ⟼ Bad ⟼ dT1 ⟼ dT2 ⟼ dO ⟼ dF ⟼ dBad ⟼
      (ev_hastype T2 (_ ⟼ T3) F O
      	  ? (eq_hastype T2 T1 O (t_eq_empty_eta Bad T1 T2 ? ? ?) ?));;

Definition LF arrow : (T1:texp) ⟶ (T2:texp) ⟶ texp := T1 ⟼ T2 ⟼ (@Pi T1 (_ ⟼ T2));;

Theorem LF ∏_istype1 : (T1:texp) ⟶ (T2:texp) ⟶
	istype T1 ⟶
        ((x:oexp) ⟶ hastype x T1 ⟶ istype T2) ⟶ istype (arrow T1 T2)
	:=
        T1 ⟼ T2 ⟼ dT1 ⟼ dT2 ⟼ (∏_istype T1 (_ ⟼ T2) dT1 dT2);;

Theorem LF λ_hastype1 : (T1:texp) ⟶ (T2:texp) ⟶ (O:oexp⟶oexp) ⟶
      ((x:oexp) ⟶ hastype x T1 ⟶ hastype (O x) T2) ⟶
      hastype (@lambda T1 O) (arrow T1 T2)
      :=
      T1 ⟼ T2 ⟼ O ⟼ dT2 ⟼ (λ_hastype T1 (_ ⟼ T2) O dT2);;

Definition LF ev1 : (F:oexp) ⟶ (O:oexp) ⟶ (T1:texp) ⟶ (T2:texp) ⟶ oexp
	   	  := F ⟼ O ⟼ T1 ⟼ T2 ⟼ (@ev F O T1 (_ ⟼ T2));;

Theorem LF ev_hastype1 : (T1:texp) ⟶ (T2:texp) ⟶ (F:oexp) ⟶ (O:oexp) ⟶
      hastype F (arrow T1 T2) ⟶ hastype O T1 ⟶ hastype (ev1 F O T1 T2) T2
      :=
      T1 ⟼ T2 ⟼ F ⟼ O ⟼ dF ⟼ dO ⟼ (ev_hastype T1 (_ ⟼ T2) F O dF dO);;

Theorem LF compose :
      (T:texp) ⟶ (istype T) ⟶
      (U:texp) ⟶ (istype U) ⟶
      (V:texp) ⟶ (istype V) ⟶
      hastype
      (@lambda
        (arrow T U)
	(f ⟼ (@lambda (arrow U V)
	      (g ⟼ (@lambda T
	      	      (t ⟼ (ev1 g (ev1 f t T U) U V)))))))
      (arrow (arrow T U) (arrow (arrow U V) (arrow T V)))
      :=
      T ⟼ dT ⟼ U ⟼ dU ⟼ V ⟼ dV ⟼
      (λ_hastype1 (arrow T U) (arrow (arrow U V) (arrow T V))
	(f ⟼ (@lambda (arrow U V)
	      (g ⟼ (@lambda T
	      	      (t ⟼ (ev1 g (ev1 f t T U) U V))))))
	(f ⟼ df ⟼ (
	  (λ_hastype1 (arrow U V) (arrow T V)
	      (g ⟼ (@lambda T
	      	      (t ⟼ (ev1 g (ev1 f t T U) U V))))
	      (g ⟼ dg ⟼ (λ_hastype1 T V
		      (t ⟼ (ev1 g (ev1 f t T U) U V))
		      (t ⟼ dt ⟼ (ev_hastype1 U V g
		      			(ev1 f t T U)
					?
					(ev_hastype1 T U f t ? ?)))))))));;

#   Local Variables:
#   compile-command: "make -C .. ts-elf "
#   End:
