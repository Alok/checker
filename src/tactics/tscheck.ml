(** Implement the binary equivalence algorithms from sections 5 and 6 of the paper as type checker for TS:

    [EEST]: Extensional Equivalence and Singleton Types
    by Christopher A. Stone and Robert Harper
    ACM Transactions on Computational Logic, Vol. 7, No. 4, October 2006, Pages 676-722.

*)

open Printf
open Printer
open Typesystem
open Lfcheck
open Error
open Helpers

let see env n x = printf "\t  %s = %a\n%!" n _e (env,x)

(** returns a term y and a derivation of hastype y t and a derivation of oequal x y t *)
let rec head_reduction (env:environment) (t:expr) (dt:expr) (x:expr) (dx:expr) : expr * expr * expr =
  (* dt : istype t *)
  (* dx : hastype x t *)
  raise NotImplemented

(** returns a term y and a derivation of hastype y t and a derivation of oequal x y t *)
let rec head_normalization (env:environment) (t:expr) (dt:expr) (x:expr) (dx:expr) : expr * expr * expr =
  (* dt : istype t *)
  (* dx : hastype x t *)
  raise NotImplemented

(** returns a derivation of oequal x y t *)
let rec term_equivalence (env:environment) (x:expr) (dx:expr) (y:expr) (dy:expr) (t:expr) (dt:expr) : expr =
  (* dt : istype t *)
  (* dx : hastype x t *)
  (* dy : hastype y t *)
  raise NotImplemented

(** returns a type t and derivation of hastype x t, hastype y t, oequal x y t *)
and path_equivalence (env:environment) (x:expr) (y:expr) : expr * expr * expr =
  raise NotImplemented

(** returns a derivation of tequal t u *)
and type_equivalence (env:environment) (t:expr) (dt:expr) (u:expr) (du:expr) : expr =
  (* dt : istype t *)
  (* du : istype u *)
  raise NotImplemented

(** returns a derivation of hastype e t *)
let rec type_check (env:environment) (e:expr) (t:expr) (dt:expr) : expr =
  (* dt : istype t *)
  (* see figure 13, page 716 [EEST] *)
  let (s,ds,h) = type_synthesis env e in	(* ds : istype x ; h : hastype e s *)
  if Alpha.UEqual.term_equiv empty_uContext 0 s t then h
  else
  let e = type_equivalence env s ds t dt in	(* e : tequal s t *)
  ignore e;
  raise NotImplemented			(* here we'll apply the rule "cast" *)

(** returns a type t and derivations of istype t and hastype x t *)
and type_synthesis (env:environment) (x:expr) : expr * expr * expr =
  (* assume nothing *)
  (* see figure 13, page 716 [EEST] *)

  (* match unmark e with *)
  (* | BASIC(O O_lambda, tx) -> ( *)
  (*     let (t,x) = args2 tx in *)

  raise NotImplemented

(** returns a derivation of istype t *)
let type_validity (env:environment) (t:expr) : expr =
  raise NotImplemented

(** returns a term y and a derivation of hastype y t and a derivation of oequal x y t *)
let rec term_normalization (env:environment) (t:expr) (dt:expr) (x:expr) (dx:expr) : expr * expr * expr =
  (* dt : istype t *)
  (* dx : hastype x t *)
  raise NotImplemented

(** returns the type t of x and derivations of istype t and hastype x t  *)
and path_normalization (env:environment) (x:expr) : expr * expr * expr =
  raise NotImplemented

let rec type_normalization (env:environment) (t:expr) : expr =
  raise NotImplemented

let self = nowhere 1234 (cite_tactic "tscheck" END)

let rec tscheck surr env pos tp args =
  if tactic_tracing then printf "tactic: tscheck: tp = %a\n%!" _t (env,tp);
  match unmark tp with
  | J_Basic(J_istype,[t]) -> (
      if tactic_tracing then see env "t" t;
      match unmark t with
      | BASIC(T T_Pi,args) -> (
          let (a,b) = args2 args in
          if tactic_tracing then (see env "a" a; see env "b" b);
          TacticSuccess ( with_pos_of t (BASIC(V (Var (id "∏_istype")), a ** b ** SND(self ** self ** END))) )
         )
      | _ -> Default.default surr env pos tp args
      )
  | J_Basic(J_hastype,[x;t]) -> (
      if tactic_tracing then printf "tactic: tscheck\n\t  x = %a\n\t  t = %a\n%!" _e (env,x) _e (env,t);
      try
        let dt = type_validity env t in (* we should be able to get this from the context *)
	TacticSuccess (type_check env x t dt)
      with
	NotImplemented|Args_match_failure -> TacticFailure
     )
  | J_Pi(v,a,b) -> (
      match tscheck surr (local_lf_bind env v a) (get_pos tp) b args with
      | TacticSuccess e -> TacticSuccess (with_pos pos (TEMPLATE(v,e)))
      | TacticFailure as r -> r)
  | _ -> Default.default surr env pos tp args

(*
  Local Variables:
  compile-command: "make -C ../.. src/tactics/tscheck.cmo "
  End:
 *)
