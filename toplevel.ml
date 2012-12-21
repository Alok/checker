(** Declaration of toplevel commands. *)

open Error
open Variables
open Typesystem

type command' = 
  | AxiomTS of string * lf_expr
  | AxiomLF of string * lf_type
  | Rule of int list * string * lf_type
  | CheckLF of lf_expr
  | CheckLFtype of lf_type
  | CheckTS of lf_expr
  | UVariable of string list * (lf_expr * lf_expr) list
  | Variable of string list
  | Alpha of lf_expr * lf_expr
  | Theorem of (position * string * lf_expr * lf_type)
  | CheckUniverses
  | Show of int option
  | End

type command = Error.position * command'
