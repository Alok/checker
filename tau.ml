open Typesystem

let rec taupos (pos:position) env o =
  let rec tau (env:environment_type) = function
    | POS(pos,e) -> taupos pos env e
    | UU _ | TT_variable _ -> raise InternalError
    | OO_variable v -> (
	try List.assoc v env.oc
	with Not_found -> 
	    raise (TypingError(get_pos o, "unbound variable, not in context: " ^ (Printer.ovartostring' v))))
    | Expr(h,args) -> (
	match h with
	| BB _ -> raise InternalError
	| TT _ -> raise InternalError
	| OO oh -> (
	    match oh with
	    | OO_emptyHole -> raise (TypingError(pos, "empty hole, type undetermined, internal error"))
	    | OO_numberedEmptyHole n -> raise (TypingError(pos, "empty hole, type undetermined, internal error"))
	    | OO_u -> (
		match args with 
		| [x] -> make_TT_U (with_pos pos (UU (Uplus(get_u x,1))))
		| _ -> raise InternalError)
	    | OO_j -> (
		match args with 
		| [m1;m2] -> make_TT_Pi (make_TT_U m1) ((Nowhere,OVarUnused), make_TT_U m2)
		| _ -> raise InternalError)
	    | OO_ev -> (
		match args with 
		| [f;o;Expr(BB x,[t])] -> Substitute.subst [(strip_pos_var x,o)] t
		| _ -> raise InternalError)
	    | OO_lambda -> (
		match args with 
		| [t;Expr(BB x,[o])] -> make_TT_Pi t (x, tau (obind (x,t) env) o)
		| _ -> raise InternalError)
	    | OO_forall -> (
		match args with 
		| u :: u' :: _ -> make_TT_U (UU (Umax(get_u u, get_u u')))
		| _ -> raise InternalError)
	    | OO_def_app d -> raise NotImplemented
	    | OO_numeral i -> make_TT_nat
	    | OO_pair -> raise NotImplemented
	    | OO_pr1 -> raise NotImplemented
	    | OO_pr2 -> raise NotImplemented
	    | OO_total -> raise NotImplemented
	    | OO_pt -> raise NotImplemented
	    | OO_pt_r -> raise NotImplemented
	    | OO_tt -> make_TT_Pt
	    | OO_coprod -> raise NotImplemented
	    | OO_ii1 -> raise NotImplemented
	    | OO_ii2 -> raise NotImplemented
	    | OO_sum -> raise NotImplemented
	    | OO_empty -> raise NotImplemented
	    | OO_empty_r -> raise NotImplemented
	    | OO_c -> raise NotImplemented
	    | OO_ic_r -> raise NotImplemented
	    | OO_ic -> raise NotImplemented
	    | OO_paths -> raise NotImplemented
	    | OO_refl -> raise NotImplemented
	    | OO_J -> raise NotImplemented
	    | OO_rr0 -> raise NotImplemented
	    | OO_rr1 -> raise NotImplemented
	   )
       )
  in tau env o

let tau = taupos Nowhere

(*

let rec tau (env:environment_type) o = (
  match strip_pos o with
  | O_emptyHole -> raise (TypingError(get_pos o, "empty hole, type undetermined, internal error"))
  | O_numberedEmptyHole _ -> raise (TypingError(get_pos o, "empty hole, type undetermined, internal error"))
  | O_numeral _ -> with_pos_of o T_nat
  | O_variable v -> (
      try List.assoc v env.oc
      with
	Not_found -> 
	  raise (TypingError(get_pos o, "unbound variable, not in context: " ^ (Printer.ovartostring' v)))
     )
  | O_u x -> with_pos_of o (T_U (nowhere(Uplus(x,1))))
  | O_j (m1,m2) -> with_pos_of o (T_Pi(with_pos_of m1 (T_U m1),(with_pos_of m2 OVarUnused,with_pos_of m2 (T_U m2))))
  | O_ev (o1,o2,(x,t)) -> Substitute.tsubst [(strip_pos x,o2)] t
  | O_lambda (t,(x,o)) -> with_pos_of o (T_Pi(t, (x, tau (obind (strip_pos x,t) env) o)))
  | O_forall (m1,m2,_,(_,_)) -> with_pos_of o (T_U (with_pos_of o (Umax(m1, m2))))
  | O_pair _
  | O_pr1 _
  | O_pr2 _
  | O_total _ -> raise NotImplemented
  | O_pt -> with_pos_of o (T_U uuu0)
  | O_pt_r (o',(x,t)) -> with_pos_of o (T_Pi(with_pos_of o T_Pt,(x, t)))
  | O_tt -> with_pos_of o T_Pt
  | O_coprod _
  | O_ii1 _
  | O_ii2 _
  | O_sum _ -> raise NotImplemented
  | O_empty -> with_pos_of o T_Empty
  | O_empty_r (t,o) -> t
  | O_c _
  | O_ic_r _
  | O_ic _
  | O_paths _
  | O_refl _
  | O_J _
  | O_rr0 _
  | O_rr1 _ -> raise NotImplemented
  | O_def (d,u,t,c) -> raise NotImplemented
 )

*)
