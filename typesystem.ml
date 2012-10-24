(**

Type system TS

@author Dan Grayson

    *)

(**

This file encodes the type system TS developed in the paper {i A universe
polymorphic type system}, by Vladimir Voevodsky, the version dated October,
2012.

  *)

(** Object variable. *)
type oVar = OVar of string

(** Type variable. *)
type tVar = TVar of string

(** Universe variable. *)
type uVar = UVar of string

(** A u-level expression, M, is constructed inductively as: n, v, M+n, or
    max(M,M'), where v is a universe variable and n is a natural number. *)
type uLevel =
  | Uint of int
	(** Here 0 denotes the smallest universe, 1 is its successor, and so on.
	    The smallest universe is the one that [pt] lives in. *)
  | Uvariable of uVar
	(** A u-level variable. *)
  | Uplus of uLevel * int
	(** A pair (M,n), denoting M+n, the n-th successor of M.  Here n should be nonnegative *)
  | Umax of uLevel * uLevel
	(** A pair (M,M') denoting max(M,M'). *)

(** A universe context is a list of universe variables and a list of equations between two u-level expressions. *)
type uContext =
    uVar list * (uLevel * uLevel) list

type expr =
    (* TS0 *)
  | ULevel of uLevel
	(** Universe term, \[M\]. *)
  | Texpr of tExpr
	(** Type term. *)
  | Oexpr of oExpr
	(** Object term. *)
    (* TS1 *)
    (* TS2 *)

(** [tBinding] is the type of pairs (x,T) where x is an o-variable and T is a type term.  The
 variable [x] is thereby considered bound within [T]. *)
and tBinding =
  | Tbinding of oVar * tExpr

(** [oBinding] is the type of pairs (x,y) where x is an o-variable and y is an o-expression.  The
 variable [x] is thereby considered bound within [y]. *)
and oBinding =
  | Obinding of oVar * oExpr

and toBinding =
  | TObinding of oVar * tExpr * oBinding

and ooBinding =
  | OObinding of oVar * oExpr * oBinding

and ttoBinding =
  | TTObinding of oVar * tExpr * toBinding

and oooBinding =
  | OOObinding of oVar * oExpr * ooBinding

and tBinding2 =
  | Tbinding2 of oVar * oVar * tExpr

(** [tExpr] is the type of T-expressions. *)
and tExpr =
  (* TS0 *)
  | Tvariable of tVar
  | El of oExpr
	(** [El]; converts an object term into the corresponding type term *)
  | ElUu of uLevel
	(** [ElUu U]; a u-level expression, as a type *)
  | ElForall of tExpr * tBinding
	(** [ElForall(T,Bd(x,T')) <--> \[Pi;x\](T,T')] *)
    (* TS1 *)
  | ElTotal of tExpr * tBinding
	(** [ElTotal(T,Bd(x,T')) <--> \[Sigma;x\](T,T')] *)
    (* TS2 *)
  | ElPt
      (** Corresponds to [Pt] in the paper; the unit type *)
    (* TS3 *)
  | ElCoprod of tExpr * tExpr
  | ElCoprod2 of tExpr * tExpr * tBinding * tBinding * oExpr
      (* TS4 *)
  | ElEmpty
      (** The empty type.  
	  
	  Voevodsky doesn't list this explicitly in the definition of TS4, but it gets used in derivation rules, so I added it.
	  Perhaps he intended to write [El(Empty)] for it. *)
      (* TS5 *)
  | ElIc of tExpr * oExpr * ttoBinding
      (* TS6 *)
  | ElPaths of tExpr * oExpr * oExpr
      (** Identity type; paths type. *)
      (* TS7 *)
      
(** [oExpr] is the type of o-expressions. *)
and oExpr =
    (* TS0 *)
  | Ovariable of oVar
	(** An o-variable. *)
  | Uu of uLevel
	(** [u]; universe as an object. *)
  | Jj of uLevel * uLevel
	(** [j]; ElUu -> U' *)
  | Ev of oExpr * oExpr * tBinding
	(** [Ev(f,o,Bd(x,T)) <--> \[ev;x\](f,o,T)]
	    
	    Application of the function [f] to the argument [o].
	    
	    Here [T], with the type of [o] replacing [x], gives the type of the result. *)
  | Lambda of tExpr * oBinding
	(** [Lambda(T,Bd(x,o)) <--> \[lambda;x\](T,o)] *)
  | Forall of uLevel * uLevel * oExpr * oBinding
	(** [Forall(M,M',o,Bd(x,o')) <--> \[forall;x\]([M],[M'],o,o')]
	    
	    [Forall] is the object term corresponding to [ElForall].
	    The type of the term is given by the max of the two u-levels. *)
	(* TS1 *)
  | Pair of oExpr * oExpr * tBinding
	(** [Pair(a,b,Bd(x,T)) <--> \[pair;x\](a,b,T)]
	    
	    An instance of [ElTotal]. *)
  | Pr1 of tExpr * tBinding * oExpr
	(** [Pr1(T,Bd(x,T'),o) <--> \[pr1;x\](T,T',o)] *)
  | Pr2 of tExpr * tBinding * oExpr
	(** [Pr2(T,Bd(x,T'),o) <--> \[pr2;x\](T,T',o)] *)
  | Total of uLevel * uLevel * oExpr * oBinding
	(** Corresponds to [total] or [prod] in the paper. *)
	(* TS2 *)
  | Pt
      (** Corresponds to [\[pt\]] in the paper. *)
      
  | Pt_r of oExpr * tBinding
	(** [Pt_r(o,Bd(x,T)) <--> \[pt_r;x\](o,T)]
	    
	    [Pt_r] is the eliminator for [ElPt]. *)
  | Tt
      (** [Tt <--> \[tt\]()]
	  
	  [Tt] is the unique instance of the unit type [ElPt]. *)
      (* TS3 *)
  | Coprod of uLevel * uLevel * oExpr * oExpr
	(** The type of the term is given by the [max] of the two u-levels. *)
  | Ii1 of tExpr * tExpr * oExpr
	(** The type of a term [Ii1(T,T',o)] is [ElCoprod(T,T')]; here [o] has type [T] *)
  | Ii2 of tExpr * tExpr * oExpr
	(** The type of a term [Ii2(T,T',o)] is [ElCoprod(T,T')]; here [o] has type [T'] *)
  | Sum of tExpr * tExpr * oExpr * oExpr * oExpr * tBinding
	(** The type of a term [Sum(T,T',s,s',o,Bd(x,S))] is [S], with [x] replaced by [o]. *)
	(* TS4 *)
  | Empty
      (** The type of [Empty] is the smallest universe, [Uint 0]. *)
  | Empty_r of tExpr * oExpr
	(** The elimnination rule for the empty type.

	    The type of [Empty_r(T,o)] is [T].  Here the type of [o] is [ElEmpty], the empty type. *)
  | Cc of tExpr * oExpr * ttoBinding * oExpr * oExpr
	(** Corresponds to [c] in the paper. *)
  | IC_r of tExpr * oExpr * ttoBinding * oExpr * tBinding2 * oExpr
	(** IC_r is the elimination rule for inductive types (W-types) *)
  | Ic of uLevel * uLevel * uLevel * oExpr * oExpr * oooBinding
	(** Corresponds to [ic].  Its type is the max of the three u-level expressions. *)
	(* TS6 *)
  | Paths of uLevel * oExpr * oExpr * oExpr
	(** The object corresponding to the identity type [ElPaths].  

	    Its type is the type corresponding to the given universe level. *)
  | Refl of tExpr * oExpr
	(** Reflexivity, or the constant path. 
	    
	    The type of [Refl(T,o)] is [ElPaths(T,o,o)]. *)
  | J of tExpr * oExpr * oExpr * oExpr * oExpr * tBinding2
	(** The elimination rule for ElPaths; Id-elim.

	    The type of [J(T,a,b,q,i,Tbinding2(x,e,S))] is [S\[b/x,i/e\]]. *)
      (* TS7 *)
   | Rr0 of uLevel * uLevel * oExpr * oExpr * oExpr
	 (** Resizing rule.

	     The type of [Rr0(M_2,M_1,s,t,e)] is [ElUu(M_1)], resized downward from [ElUu M_2].
	     *)
   | Rr1 of uLevel * oExpr * oExpr
	 (** Resizing rule.

	     The type of [Rr1(M,a,p)] is [ElUu(Uint 0)], resized downward from [ElUu M].
	     *)


type typingContext = (oVar * tExpr) list
      (** context; [Gamma]; to be thought of as a function from variables to T-expressions *)
      
let emptyContext : typingContext = []

(*
 For emacs:
 Local Variables:
  coding: latin-1
  compile-command: "make typesystem.cmo doc "
  comment-column: 70
 End:
*)
