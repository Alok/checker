open Errorcheck open Tau open Substitute open Typesystem open Lfcheck 
open Names open Printer open Printf open Helpers

(** fill in argument 3 of @ev[f,x,T,_] using tau *)
let ev3 (surr:surrounding) env pos t args =
  match surr with 
  | (_,S_body,_,_) :: (env,S_expr_list'(3,O O_ev, ARG(t,ARG(x,ARG(f,END))),_), _, _) :: _ ->
	let tf = tau env f in (
	match unmark tf with
	| BASIC(T T_Pi, ARG(_,ARG(t,END))) -> TacticSuccess (apply_args t var_0)
	| _ -> ts_function_expected env f tf)
  | _ -> TacticFailure

(*
  Local Variables:
  compile-command: "make -C ../.. src/tactics/ev3.cmo "
  End:
 *)
