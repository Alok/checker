open Typesystem

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
