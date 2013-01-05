# -*- coding: utf-8 -*-

Mode Pairs.

Include "rules/TS6.ts".

# resizing rules
# [rr0], [rr1]

Definition pi1 { ⊢ T U Type } ⊢ [∏;_](T,U) Type ::= (_, T ⟼ U ⟼ (pi₂ T (_⟼U₁,_⟼U))).

Definition lambda1 { ⊢ T U Type } { t : T ⊢ o : U } ⊢ [λ](T,o) : [∏;_](T,U) ::= (_, T ⟼ U ⟼ (λh₂ T (_⟼U₁,_⟼U))).

Definition ev1 { ⊢ T U Type, f : [∏;_](T,U), o : T } ⊢ [ev;_](f,o,U) : U ::= (_, T ⟼ U ⟼ (ev₂ T (_⟼U₁,_⟼U))).

Definition Iscontr { ⊢ X Type } ⊢ [Σ;x](X,[∏;y](X,[Id](X,y,x))) Type ::= 
   (_, X ⟼ (Σ_istype₂ X (x ⟼ ([∏] X₁ (y ⟼ ([Id] X₁ y x))), 
   			 x ⟼ (pi₂ X (y ⟼ ([Id] X₁ y x₁), y ⟼ (Id_istype₂ X y x)))))).

Definition Hfiber { ⊢ X Y Type, f : [∏;_](X,Y), y:Y } ⊢ [Σ;x](X,[Id](Y,[ev;_](f,x,Y),y)) Type ::=
   (_, X ⟼ Y ⟼ f ⟼ y ⟼ 
     (Σ_istype₂ X (x ⟼ ([Id] Y₁ ([ev] f₁ x (_ ⟼ Y₁)) y₁), x ⟼ (Id_istype₂ Y (ev1₂ X Y f x) y)))).

Definition Isweq { ⊢ X Y Type, f : [∏;_](X,Y) } ⊢ [∏;y](Y,[Iscontr]([Hfiber](X,Y,f,y))) Type 
   ::= (_,X ⟼ Y ⟼ f ⟼ (pi_2 Y (y ⟼ (Iscontr_1 (Hfiber_1 X_1 Y_1 f_1 y)), y ⟼ (Iscontr_2 (Hfiber_2 X Y f y))))).

#   Local Variables:
#   compile-command: "make -C .. rules7 "
#   End:
