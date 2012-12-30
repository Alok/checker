(** Tactics. *)

open Printf

open Error
open Variables
open Typesystem
open Names
open Tau
open Printer
open Lfcheck

let show_surr (i,e,t) =
  let _ = match i with
  | Some i -> printf "  argument %d in %a\n" i _e e
  | None ->   printf "  in expression %a\n"   _e e in
  let _ = match t with
  | Some t -> printf "        of type %a\n" _t t
  | None -> () in
  flush stdout

let show_surroundings (surr:surrounding) = 
  List.iter show_surr surr

let add_tactic name f = tactics := (name,f) :: !tactics

(** find the first variable in the context of the right type and return it *)
let assumption surr env pos t =
  let rec repeat = function
    | (v,u) :: envp -> (
	try
	  Lfcheck.type_equivalence env t u;
	  TacticSuccess(var_to_lf v)
	with TypeEquivalenceFailure -> 
	  repeat envp)
    | [] -> TacticFailure
  in repeat env

(** fill in the third argument of [ev](f,x,_) using tau *)
let ev3 (surr:surrounding) env pos t =
  (* This code was formerly a part of the file fillin.ml, removed. *)
  match surr with 
  | (_, (pos,APPLY( O O_ev, ARG(f,_))), _) :: _ -> (
      try
	let tf = 
	  tau env f 
	in (
	match unmark tf with
	| APPLY(T T_Pi, ARG(_,ARG(t,END))) -> TacticSuccess t
	| _ -> raise (TypeCheckingFailure(
		      env, [
		      get_pos f,
		      "expected a TS function:\n    " ^ ts_expr_to_string f ^
		      "\n  : " ^ ts_expr_to_string tf ])))
	  
      with NotImplemented ->
	printf "warning: ev3: \"tau\" not implemented for %a\n%!" _e f;
	TacticFailure)
  | (i,e,t) :: _ ->
      let i = match i with Some i -> i | None -> -1 in
      printf "ev3 ( %d , %a ) ?\n%!" i _e (e);
      internal ()
  | [] -> 
      printf "%a: ev3 ?\n%!" _pos pos;
      internal ()

let default surr env pos t = 
  match unmark t with
  | F_Singleton(e,_) -> TacticSuccess e
  | F_Apply((F_hastype|F_istype),_) -> assumption surr env pos t
  | _ -> 
      printf "Default tactic failure in hole of type %a\n%!" _t t;
      show_surroundings surr;
      TacticFailure

let _ = 
  add_tactic "ev3" ev3;
  add_tactic "a" assumption;
  add_tactic "default" default

(* 
  Local Variables:
  compile-command: "make tactics.cmo "
  End:
 *)