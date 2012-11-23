(** Filling in the unknown types in an expression, after parsing.

    For example, the third branch of [\[ev;x\](f,o,_)], written in short form
    [f o], needs to be filled in, based on the context, using [tau].

    This file is not completely implemented: some binders are ignored.
 *)

open Typesystem
open Tau

let rec fillinlist pos env es = List.map (fillin pos env) es
and fillin pos env = function
    | LAMBDA(v,bodies) -> raise Error.NotImplemented
    | POS(pos,e) -> POS(pos, match e with
      | Variable _ as v -> v
      | APPLY(label,branches) -> (
	  match label with
	  | UU _ -> e
	  | OO OO_emptyHole | OO OO_numberedEmptyHole _ -> raise (Error.TypingError(pos,"empty o-expression hole, no method for filling"))
	  | TT TT_EmptyHole | TT TT_NumberedEmptyHole _ -> raise (Error.TypingError(pos,"empty t-expression hole, no method for filling"))
	  | OO OO_lambda -> (
	      match branches with 
	      | [t; LAMBDA( x,[o])] -> 
		  make_OO_lambda (fillin pos env t)  (x, fillin pos (obind (x,t) env) o)
	      | _ -> raise Error.Internal)
	  | TT TT_Pi -> (
	      match branches with 
	      | [t; LAMBDA( x,[o])] -> 
		  make_TT_Pi (fillin pos env t)  (x, fillin pos (obind (x,t) env) o)
	      | _ -> raise Error.Internal)
	  | OO OO_forall -> (
	      match branches with 
	      | [m; m'; n; LAMBDA( x,[o])] -> 
		  make_OO_forall m m' 
		    (fillin pos env n)
		    (x, fillin pos (obind (x,with_pos (get_pos n) (make_TT_El n)) env) o)
	      | _ -> raise Error.Internal)
	  | OO OO_ev -> (
	      match branches with 
		[f;p] -> (
		  match strip_pos(tau env f) with
		  | APPLY(TT TT_Pi, [t1; LAMBDA( x,[t2])])
		    -> make_OO_ev (fillin pos env f) (fillin pos env p) (x, (fillin pos (obind (x,t1) env) t2))
		  | _ -> raise (Error.TypingError(get_pos f,"expected a product type")))
	      | [f; p; LAMBDA( x,[t2])] ->
		  let p = fillin pos env p in
		  let t1 = tau env p in
		  make_OO_ev (fillin pos env f) p (x, (fillin pos (obind (x,t1) env) t2))
	      | _ -> APPLY (label, fillinlist pos env branches)
	     )
	  | _ -> APPLY (label, fillinlist pos env branches)
	 ))

let fillin = fillin Error.Nowhere
