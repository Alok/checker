(** Exceptions, experiments, error message handling, and source code positions. *)

open Positions

let show_rules = false

let show_definitions = true

let try_normalization = true

let env_limit = Some 20

let tactic_tracing = false

let lesser_debug_mode = true

let debug_mode = ref false

let debug_subst = false

let internal_location_trap = 0

let new_counter () = let n = ref 0 in fun () -> incr n; !n

let proof_general_mode = ref false

let trap () = ()			(* set a break point here *)

let notail x = x			(* insert into code to termporarily prevent tail recursion *)

let error_count = ref 0

exception DebugMe
exception GeneralError of string
exception NotImplemented
exception Unimplemented of string
exception Internal
exception VariableNotInContext
exception NoMatchingRule
exception Eof
exception FalseWitness
exception GoBack of int
exception GoBackTo of int

exception MarkedError of position * string

let lexbuf_position lexbuf =
    Position ( Lexing.lexeme_start_p lexbuf, Lexing.lexeme_end_p lexbuf )

let errfmt = function
  | Position(p,q)
    -> "File \"" ^ p.Lexing.pos_fname ^ "\", "
      ^ (if p.Lexing.pos_lnum = q.Lexing.pos_lnum
	 then "line " ^ string_of_int p.Lexing.pos_lnum
	 else "lines " ^ string_of_int p.Lexing.pos_lnum ^ "-" ^ string_of_int q.Lexing.pos_lnum)
      ^ ", "
      ^ (let i = p.Lexing.pos_cnum-p.Lexing.pos_bol+1
         and j = q.Lexing.pos_cnum-q.Lexing.pos_bol in
         if i = j
	 then "character " ^ string_of_int i
         else "characters " ^ string_of_int i ^ "-" ^ string_of_int j)
  | Nowhere(i,j) -> "internal:" ^ string_of_int i ^ ":" ^ string_of_int j

let bump_error_count pos =
  incr error_count;
  if not !proof_general_mode && !error_count >= 5 then (
    Printf.fprintf stderr "%s: too many errors, exiting.\n%!" (errfmt pos);
    raise (Failure "exiting"));
  flush stderr; flush stdout		(*just in case*)

let min_pos p q =
  if p.Lexing.pos_fname != q.Lexing.pos_fname then (trap(); raise Internal);
  if p.Lexing.pos_cnum < q.Lexing.pos_cnum then p else q

let max_pos p q =
  if p.Lexing.pos_fname != q.Lexing.pos_fname then (trap(); raise Internal);
  if p.Lexing.pos_cnum > q.Lexing.pos_cnum then p else q

let merge_pos p q =
  match (p,q) with
  | Position _ , Nowhere _ -> p
  | Nowhere _ , Position _ -> q
  | Nowhere _ , Nowhere _ -> p
  | Position(s,e) , Position(s',e') -> Position(min_pos s s', max_pos e e')

let unmark ((_:position), x) = x
let get_pos ((pos:position), _) = pos
let errpos x = errfmt (get_pos x)
let with_pos (pos:position) e = (pos, e)
let new_pos (pos:position) ((_:position),e) = (pos, e)
let with_pos_of ((pos:position),_) e = (pos,e)
let nowhere_ctr = ref 0
let seepos pos = Printf.fprintf stderr "%s: ... debugging ...\n%!" (errfmt pos)

let no_pos i =
  incr nowhere_ctr;
  if !nowhere_ctr = internal_location_trap then (trap(); raise DebugMe);
  Nowhere(i, !nowhere_ctr)
let nowhere i x = (no_pos i,x)
let nopos i = errfmt (no_pos i)

(*
  Local Variables:
  compile-command: "make -C .. src/error.cmo "
  End:
 *)
