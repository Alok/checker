(** Tactics. *)

open Typesystem

let _ = add_tactic "ev3" Ev3.ev3
let _ = add_tactic "default" Default.default
let _ = add_tactic "a" Assumption.assumption

(* 
  Local Variables:
  compile-command: "make -C ../.. build "
  End:
 *)