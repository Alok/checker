(** Exceptions, error message handling, and source code positions. *)

let debug_mode = ref false

let nowhere_trap = ref 0

(* raise an exception when a certain fresh variable is generated *)
let genctr_trap = 0

let trap () = ()			(* set a break point here *)

let notail x = x			(* insert into code to termporarily prevent tail recursion *)

exception DebugMe
exception GeneralError of string
exception GensymCounterOverflow
exception NotImplemented
exception Unimplemented of string
exception Internal
exception VariableNotInContext
exception NoMatchingRule
exception Eof

type position =
  | Position of Lexing.position * Lexing.position (** start, end *)
  | Nowhere of int * int

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
  | Nowhere(i,j) -> "nowhere:" ^ string_of_int i ^ ":" ^ string_of_int j

type 'a marked = position * 'a
let unmark ((_:position), x) = x
let get_pos ((pos:position), _) = pos
let errpos x = errfmt (get_pos x)
let with_pos (pos:position) e = (pos, e)
let with_pos_of ((pos:position),_) e = (pos,e)
let nowhere_ctr = ref 0
let seepos pos = Printf.fprintf stderr "%s: ... debugging ...\n" (errfmt pos); flush stderr

let no_pos i = 
  incr nowhere_ctr;
  if !nowhere_ctr = !nowhere_trap then raise DebugMe;
  Nowhere(i, !nowhere_ctr)
let nowhere i x = (no_pos i,x)
let nopos i = errfmt (no_pos i)
