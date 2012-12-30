# -*- coding: utf-8 -*-

# All the base judgments, and what would satisfy them as evidence.
# The binders are present in order to produce well-formed types.
# ( Here "with" means a satisfactory term would be a pair. )

Mode Relative.

Check TS : (T:texp) =>             [ T Type ].          # a proof that T is a type

Check TS : (T:texp) =>             |- T Type.           # T with a proof that T is a type

Check TS :                         Type.                # a t-expression with a proof that it is a type

Check TS : (T:texp) => (t:oexp) => [ t : T ].           # a proof that t has type T

Check TS : (T:texp) => (t:oexp) => |- t : T.            # t with a proof that t has type T

Check TS : (T:texp) =>             : T.                 # an o-expression with a proof that it has type T

Check TS : (T:texp) => (U:texp) => [ T = U ].           # a proof that T = U (type equality)

Check TS : (T:texp) => (t:oexp) 
                    => (u:oexp) => [ t = u : T ].       # a proof that t = u : T (object equality)

# Here are the base judgments again, but this time with binders for pairs.  For example,
# { |- T Type } denotes a parameter T whose value is a t-expression with a proof that it is a type.

Check TS : { |- T Type }        [ T Type ].             # T with a proof that T is a type

Check TS : { |- T Type }        |- T Type.              # T with a proof that T is a type

Check TS :                      Type.                   # a t-expression with a proof that it is a type

Check TS : { |- T Type, t:T }   [ t : T ].              # a proof that t has type T

Check TS : { |- T Type, t:T }   |- t : T.               # t with a proof that t has type T

Check TS : { |- T Type }        : T.                    # an o-expression with a proof that it has type T

Check TS : { |- T U Type }      [ T = U ].              # a proof that T = U (type equality)

Check TS : { |- T Type, t u:T } [ t = u : T ].          # a proof that t = u : T (object equality)

# Here are the judgments involving ulevel equality:

Check TS : (T:texp) => (t:oexp) => 
      		       (u:oexp) => [ t ~ u : T ].       # ulevel equivalence for o-expressions
Check TS : (T:texp) => (U:texp) => [ T ~ U Type ].      # ulevel equivalence for t-expressions
Check TS : (u:uexp) => (v:uexp) => [ u ~ v Ulevel ].    # ulevel equivalence for u-expressions

Check TS : { |- T Type, t u:T }    [ t ~ u : T ].       # ulevel equivalence for o-expressions
Check TS : { |- T U Type }         [ T ~ U Type ].      # ulevel equivalence for t-expressions
Check TS : { |- u v Ulevel }       [ u ~ v Ulevel ].    # ulevel equivalence for u-expressions

# include the standard rules of inference

Include "test/rules.ts".

# Sample theorems demonstrating the syntax.

Definition Pt2 Type ::= Pt.

Theorem compose1 { ⊢ T Type, U Type, V Type, f:T⟶U, g:U⟶V, t:T } : V ::=
        T ⟼ U ⟼ V ⟼ f ⟼ g ⟼ t ⟼ ((ev U (_ ⟼ V) g (ev T (_ ⟼ U) f t CAR) CAR), 
        T' ⟼ U' ⟼ V' ⟼ f' ⟼ g' ⟼ t' ⟼ (ev U (_ ⟼ V) g (ev T (_ ⟼ U) f t CAR) CDR U' (_ ⟼ _ ⟼ V') g' (ev T (_ ⟼ U) f t CDR T' (_ ⟼ _ ⟼ U') f' t'))).

Theorem LF compose1' : T Type |- U Type |- V Type |- f :: ([Pi] T (_ ⟼ U)) |- g :: ([Pi] U (_ ⟼ V)) |- t :: T |- v :: V := 
        T ⟼ U ⟼ V ⟼ f ⟼ g ⟼ t ⟼ ((ev U (_ ⟼ V) g (ev T (_ ⟼ U) f t CAR) CAR), 
        T' ⟼ U' ⟼ V' ⟼ f' ⟼ g' ⟼ t' ⟼ (ev U (_ ⟼ V) g (ev T (_ ⟼ U) f t CAR) CDR U' (_ ⟼ _ ⟼ V') g' (ev T (_ ⟼ U) f t CDR T' (_ ⟼ _ ⟼ U') f' t'))).

Theorem compose1a { ⊢ T Type, U Type, V Type, g:U⟶V, f:T⟶U } : T⟶V ::=
        T ⟼ U ⟼ V ⟼ g ⟼ f ⟼ ((λh T (_ ⟼ V) (t ⟼ (compose1 T U V f g t CAR)) CAR),
	T' ⟼ U' ⟼ V' ⟼ g' ⟼ f' ⟼ 
		(λh T (_ ⟼ V) (t ⟼ (compose1 T U V f g t CAR)) CDR T' (_ ⟼ _ ⟼ V')
	            (t ⟼ t' ⟼ (compose1 T U V f g t CDR T' U' V' f' g' t')))).

Theorem compose2 { ⊢ u Ulevel, T:[U](u), U:[U](u), V:[U](u), g:*U ⟶ *V, f:*T ⟶ *U, t:*T } : *V ::= 
         u ⟼ T ⟼ U ⟼ V ⟼ g ⟼ f ⟼  t  ⟼ ((ev (El u U CAR   ) (_ ⟼     (El u V CAR   )) g  (ev (El u T CAR) (_ ⟼ (El u U CAR)) f t CAR) CAR),
         T' ⟼ U' ⟼ V' ⟼ g' ⟼ f' ⟼ t' ⟼  (ev (El u U CAR   ) (_ ⟼     (El u V CAR   )) g  (ev (El u T CAR) (_ ⟼ (El u U CAR)) f t CAR) CDR
	 			  	     (El u U CDR U') (_ ⟼ _ ⟼ (El u V CDR V')) g' (ev (El u T CAR) (_ ⟼ (El u U CAR)) f t CDR
					     (El u T CDR T') (_ ⟼ _ ⟼ (El u U CDR U')) f' t'))).

#Lemma A { |- u Ulevel, T U : [U](u), f : *[∀;x](u,u,T,U) } : [Pi;_](*T,*U) ::=
#                 u ⟼ T ⟼ U ⟼ f ⟼ 
#		 (cast (El u (forall u u T U)) 
#                       (pi (El u T) (El u U))
#                       (El_forall_reduction u u T U)
#		       f).
#
#Theorem compose3 { |- u Ulevel, T U V : [U](u), g : *[∀;x](u,u,U,V), f : *[∀;x](u,u,T,U), t: *T } : *V ::=
#                 u ⟼ T ⟼ U ⟼ V ⟼ g ⟼ f ⟼ t ⟼ 
#                 (ev (El u U) (El u V) (A u U V g) (ev (El u T) (El u U) (A u T U f) t)).
#
#Theorem compose4 { |- u Ulevel, T U V : [U](u), g : *[∀;x](u,u,U,V), f : *[∀;x](u,u,T,U) } : *T ⟶ *V ::=
#                 u ⟼ T ⟼ U ⟼ V ⟼ g ⟼ f ⟼ 
#		 (λh 
#			    (El u T) (El u V) 
#			    (compose3 u T U V g f) # <--- same problem here
#			    ).
#
#	need:
#
#	(o:oexp ⟶ oexp) × ((x:oexp) ⟶ 
#				hastype x (El u (T₁,T₂))₁ ⟶ 
#				hastype (o x) (El u (V₁,V₂))₁)


#Theorem A' { |- u Ulevel, T U : [U](u), f : *[∀;x](u,u,T,U) } : [Pi](*T,*U) ::=  # <-- bug here 
#                 u ⟼ T ⟼ U ⟼ f ⟼ 
#		 (cast (El u (forall u u T U)) 
#                             (pi (El u T) (El u U))
#                             (El_forall_reduction u u T U) f).
#

#   Local Variables:
#   compile-command: "make -C .. demo "
#   End: