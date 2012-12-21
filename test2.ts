
End.



Variable u0 Ulevel.




Definition E1 (u Ulevel)(K Type)(x:K) := x : K;; $a.
End. # stuff below here doesn't work yet
Definition E3 (u1 u2 u3 Ulevel)(K Type)(x1: K ⟶ [U](u1))(x2: [U]([next](u0))) := [U](u2) .
Definition E5 (u1 u2 u3 Ulevel; max (u1, u2) = max (u2, u3); u1 >= [next](u2) )(K Type)(x1: K ⟶ [U](u1))(x2: [U]([next](u0))) := [j](x1, x2) : [U](u2) .
Definition E7 (T U Type)(t:T)(u:U)(f:T ⟶ U) := f t : _.
Definition E7 (K L Type)(t:K)(g:K ⟶ [U](u0))(u:L)(f:∏ x:K, *g x) := f t : _.
Definition E6 (u1 u2 u3 Ulevel)(X1 X2 Type)(x1: X1 ⟶ [U](u1))(x2: [U]([next](u0))) := [j](x1, x2) : _ .

Definition bar (T Type) := T ⟶ T.
Definition univ (u Ulevel) := [U](u).

Definition g1 := f : T ⟶ T.
Definition g2 (T Type) := λ x:T, x : T ⟶ T.
Definition g3 (T Type)(t:T) := λ x:T, t : T ⟶ T.

Variable u v Ulevel ; u < v .
Axiom TS a : [Pt]().
Axiom LF T : texp.
Axiom LF i : (istype T).
Check Universes.



#   Local Variables:
#   compile-command: "make run2 "
#   End:
