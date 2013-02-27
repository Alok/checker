(** error messages for type checking *)

open Error
open Names
open Printer

exception TermEquivalenceFailure
exception TypeEquivalenceFailure
exception SubtypeFailure

let err env pos msg = raise (TypeCheckingFailure (env, [], [pos, msg]))

let errmissingarg env pos a = err env pos ("missing next argument, of type "^lf_type_to_string a)

let mismatch_type env pos t pos' t' = 
  raise (TypeCheckingFailure (env, [], [
         pos , "expected type " ^ lf_type_to_string t;
         pos', "to match      " ^ lf_type_to_string t']))

let mismatch_term_type env e t =
  raise (TypeCheckingFailure (env, [], [
               get_pos e, "error: expected term\n\t" ^ lf_expr_to_string e;
               get_pos t, "to be compatible with type\n\t" ^ lf_type_to_string t]))

let mismatch_term_type_type env e s t =
  raise (TypeCheckingFailure (env, [], [
               get_pos e, "error: expected term\n\t" ^ lf_expr_to_string e;
               get_pos s, "of type\n\t" ^ lf_type_to_string s;
               get_pos t, "to be compatible with type\n\t" ^ lf_type_to_string t]))

let mismatch_term_t env pos x pos' x' t = 
  raise (TypeCheckingFailure (env, [], [
                    pos , "error: expected term\n\t" ^ lf_expr_to_string x ;
                    pos',      "to match\n\t" ^ lf_expr_to_string x';
               get_pos t,       "of type\n\t" ^ lf_type_to_string t]))

let mismatch_term env pos x pos' x' = 
  raise (TypeCheckingFailure (env, [], [
                    pos , "error: expected term\n\t" ^ lf_expr_to_string x;
                    pos',      "to match\n\t" ^ lf_expr_to_string x']))

let function_expected env f t =
  raise (TypeCheckingFailure (env, [], [
                    get_pos f, "error: encountered a non-function\n\t" ^ lf_expr_to_string f;
                    get_pos t, "of type\n\t" ^ lf_type_to_string t]))

let mismatch_term_tstype_tstype env e s t =
  raise (TypeCheckingFailure (env, [], [
               get_pos e, "error: expected term\n\t" ^ ts_expr_to_string e;
               get_pos s, "of type\n\t" ^ ts_expr_to_string s;
               get_pos t, "to be compatible with type\n\t" ^ ts_expr_to_string t]))