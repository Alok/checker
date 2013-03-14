(** Implement the binary equivalence algorithms from sections 5 and 6 of the paper as a type checker for LF:

    [EEST]: Extensional Equivalence and Singleton Types
    by Christopher A. Stone and Robert Harper
    ACM Transactions on Computational Logic, Vol. 7, No. 4, October 2006, Pages 676-722.
*)

(*

  We probably don't handle types such as [Pi x:A, Singleton(B)] well.

  We should implement hash consing so the alpha equivalence testing doesn't slow things down too much.

*)

let tactic_tracing = false

open Error
open Errorcheck
open Variables
open Typesystem
open Names
open Printer
open Substitute
open Printf
open Helpers
open Tau
open Printer

let abstraction1 pos (env:environment) = function
  | ARG(t,ARG((_,LAMBDA(x, _)),_)) -> ts_bind env x t
  | _ -> env

let abstraction2 pos (env:environment) = function
  | ARG(_,ARG(_,ARG(n,ARG((_,LAMBDA(x,_)),_)))) -> ts_bind env x (get_pos n, make_T_El n)
  | _ -> env

let abstraction3 pos (env:environment) = function
  | ARG(f,ARG(_,ARG((_,LAMBDA(x, _)),_))) -> (
      try
	let tf = tau env f in (
	match unmark tf with
	| APPLY(T T_Pi, ARG(t, _)) -> ts_bind env x t
	| _ -> env)
      with TypeCheckingFailure _ | NotImplemented ->
	(* printf "%a: warning: abstraction3: \"tau\" not implemented for %a\n%!" _pos_of f _e (env,f); *)
	env)
  | _ -> env

let ts_binders = [
  ((O O_lambda, 1), abstraction1);
  ((T T_Pi, 1), abstraction1);
  ((T T_Sigma, 1), abstraction1);
  ((O O_forall, 3), abstraction2);
  ((O O_ev, 2), abstraction3)
]

let enable_ts_binders = true

let apply_ts_binder env i e =
  if not enable_ts_binders then env else
  let pos = get_pos e in
  match unmark e with
  | APPLY(h,args) -> (
      try
        (List.assoc (h,i) ts_binders) pos env args
      with
        Not_found -> env)
  | _ -> (trap(); raise Internal)

let try_alpha = true

let rec strip_singleton ((_,(_,t)) as u) = match t with
| F_Singleton a -> strip_singleton a
| _ -> u

let rec un_singleton t =
  match unmark t with
  | F_Singleton xt -> let (x,t) = strip_singleton xt in t
  | _ -> t

(* background assumption: all types in the environment have been verified *)

let apply_tactic surr env pos t args = function
  | Tactic_sequence _ -> raise NotImplemented
  | Tactic_name name ->
      let tactic =
        try List.assoc name !tactics
        with Not_found -> err env pos ("unknown tactic: " ^ name) in
      tactic surr env pos t args
  | Tactic_index n ->
      if n < List.length env.local_lf_context
      then TacticSuccess (var_to_lf_pos pos (VarRel n))
      else err env pos ("index out of range: "^string_of_int n)

let show_tactic_result env k =
  if tactic_tracing then
  (
   match k with
   | TacticSuccess e -> printf "tactic success: %a\n%!" _e (env,e)
   | TacticFailure -> printf "tactic failure\n%!" );
  k

let rec natural_type (env:environment) (x:lf_expr) : lf_type =
  if true then raise Internal;          (* this function is unused *)
  (* assume nothing *)
  (* see figure 9 page 696 [EEST] *)
  let pos = get_pos x in
  match unmark x with
  | APPLY(l,args) ->
      let t = head_to_type env pos l in
      let rec repeat i args t =
        match args, unmark t with
        | ARG(x,args), F_Pi(v,a,b) -> repeat (i+1) args (subst_type x b)
        | ARG _, _ -> err env pos "at least one argument too many"
        | CAR args, F_Sigma(v,a,b) -> repeat (i+1) args a
        | CAR _, _ -> err env pos "pi1 expected a pair (2)"
        | CDR args, F_Sigma(v,a,b) -> repeat (i+1) args b
        | CDR _, _ -> err env pos "pi2 expected a pair (2)"
        | END, F_Pi(v,a,b) -> errmissingarg env pos a
        | END, t -> t
      in nowhere 5 (repeat 0 args t)
  | LAMBDA _ -> err env pos "LF lambda expression found, has no natural type"
  | CONS _ -> err env pos "LF pair found, has no natural type"

let car_passed_term pos head args_passed = with_pos pos (APPLY(head,reverse_spine (CAR args_passed)))

let subst_car_passed_term pos head args_passed b = 
  if !debug_mode then printf "subst_car_passed_term head %a args_passed %a b %a\n%!" _h head _s args_passed _t (empty_environment,b);
  let r = subst_type (car_passed_term pos head args_passed) b in
  if !debug_mode then printf "subst_car_passed_term returns %a\n%!" _t (empty_environment,r);
  r

let rec head_reduction (env:environment) (x:lf_expr) : lf_expr =
  (* see figure 9 page 696 [EEST] *)
  (* assume x is not a pair or a function *)
  (* raises Not_found if there is no head reduction *)
  (* we work out the natural type of each partial head path in the loop below,
     while looking for singletons, instead of calling the routine natural_type *)
  let pos = get_pos x in
  match unmark x with
  | APPLY(h,args) -> (
      match h with
      | TAC _ -> raise Internal	(* all tactics should have been handled during type checking *)
      | (U _|O _|T _) -> raise Not_found (* we know the constants in our signature don't involve singleton types *)
      | head ->
	  let t = 
	    try
	      head_to_type env pos head 
	    with Not_found ->
	      printf "%a: head = %a\n%!" _pos pos _h head;
	      print_context None stdout env;
	      raise Internal
	  in
	  let args_passed = END in
	  let rec repeat t args_passed args =
	    match unmark t, args with
	    | F_Singleton s, args -> let (x,t) = strip_singleton s in apply_args x args (* here we unfold a definition *)
	    | F_Pi(v,a,b), ARG(x,args) -> repeat (subst_type x b) (ARG(x,args_passed)) args
	    | F_Sigma(v,a,b), CAR args -> repeat a (CAR args_passed) args
	    | F_Sigma(v,a,b), CDR args -> repeat (subst_car_passed_term pos head args_passed b) (CDR args_passed) args
	    | _, END -> raise Not_found
	    | _ -> 
		printf "%a: x = %a\n%a: t = %a, args_passed = %a, args = %a\n%!" _pos pos _e (env,x) _pos (get_pos t) _t (env,t) _s args_passed _s args;
		raise Internal
	  in repeat t args_passed args
     )
  | CONS _ 
  | LAMBDA _ -> raise Internal

let rec head_normalization (env:environment) (x:lf_expr) : lf_expr =
  (* see figure 9 page 696 [EEST] *)
  if !debug_mode then printf "entering head_normalization: x = %a\n%!" _e (env,x);
  try 
    let r = head_normalization env (head_reduction env x) in
    if !debug_mode then printf "leaving head_normalization: r = %a\n%!" _e (env,r);
    r    
  with Not_found -> 
    if !debug_mode then printf "leaving head_normalization, no change\n%!";
    x

let term_equiv = Alpha.UEqual.term_equiv empty_uContext 0 (* or should it be UEquivA ? *)
let type_equiv = Alpha.UEqual.type_equiv empty_uContext 0

(** Witness checking *)

let compare_var_to_expr v e =
  match unmark e with
  | APPLY(V w, END) -> v = w
  | _ -> false

let open_context t1 (env,p,o,t2) =
  let env = local_tts_declare_object env "x" t1 in
  let v = VarRel 1 in
  let v' = VarRel 0 in
  let e = var_to_lf v ** var_to_lf v' ** END in
  let p = Substitute.apply_args (rel_shift_expr 1 p) e in
  let o = Substitute.apply_args (rel_shift_expr 1 o) e in
  let t2 = Substitute.apply_args (rel_shift_expr 1 t2) e in
  (env,p,o,t2)

let unpack_El' t =
  match unmark t with
  | APPLY(T T_El',args) -> args2 args
  | _ -> raise FalseWitness

let unpack_Pi' t =
  match unmark t with
  | APPLY(T T_Pi',args) -> args2 args
  | _ -> raise FalseWitness

let unpack_ev' o =
  match unmark o with
  | APPLY(O O_ev',args) -> args4 args
  | _ -> raise FalseWitness

let unpack_lambda' o =
  match unmark o with
  | APPLY(O O_lambda',args) -> args2 args
  | _ -> raise FalseWitness

let apply_2 shift f x y = Substitute.apply_args (rel_shift_expr shift f) (x ** y ** END)

let rec check_istype env t =
  match unmark t with
  | APPLY(V (Var i), END) -> if not (isid i && is_tts_type_variable env (id_to_name i)) then err env (get_pos t) "variable not declared as a type"
  | APPLY(T th, args) -> (
      match th with
      | T_Pi' ->
	  let t1,t2 = args2 args in
	  check_istype env t1;
	  let env = local_tts_declare_object env "o" t1 in
	  let o = var_to_lf (VarRel 1) in
	  let p = var_to_lf (VarRel 0) in
	  let t2 = Substitute.apply_args (rel_shift_expr 1 t2) (o ** p ** END) in
	  check_istype env t2
      | T_U' -> ()
      | T_El' ->
	  let o,p = args2 args in
	  check_hastype env p o uuu
      | T_Proof ->
	  let p,o,t = args3 args in
	  check_hastype env p o t
      | _ -> err env (get_pos t) "invalid type, or not implemented yet.")
  | _ -> err env (get_pos t) ("invalid type, or not implemented yet: " ^ ts_expr_to_string env t)

and check_hastype env p o t =
  if false then printf "check_hastype\n p = %a\n o = %a\n t = %a\n%!" _e (env,p) _e (env,o) _e (env,t);
  match unmark p with
  | APPLY(V p', END) when is_witness_var p' -> (
      let o' = base_var p' in
      let t' =
	try tts_fetch_type env p'
	with Not_found -> err env (get_pos p) "variable not in context" in
      if not (compare_var_to_expr o' o) then err env (get_pos o) ("expected variable " ^ vartostring o');
      if not (term_equiv t t') then mismatch_term_tstype_tstype env o t' t)
  | APPLY(W wh, pargs) -> (
      match wh with
      | W_wev ->
	  let pf,po = args2 pargs in
          let f,o,t1,t2 = unpack_ev' o in
          check_hastype env po o t1;
          let u = nowhere 123 (APPLY(T T_Pi', t1 ** t2 ** END)) in
          check_hastype env pf f u;
          let t2' = Substitute.apply_args t2 (po ** o ** END) in
          if not (term_equiv t2' t) then mismatch_term_tstype_tstype env o t t2'
      | W_wlam ->
	  let p = args1 pargs in
	  let t1',o = unpack_lambda' o in
	  let t1,t2 = unpack_Pi' t in
	  if not (term_equiv t1' t1) then mismatch_term env (get_pos t) t (get_pos t1) t1;
	  let env,p,o,t2 = open_context t1 (env,p,o,t2) in
	  check_hastype env p o t2
      | W_wconv | W_wconveq | W_weleq | W_wpi1 | W_wpi2 | W_wl1 | W_wl2 | W_wevt1 | W_wevt2
      | W_wevf | W_wevo | W_wbeta | W_weta | W_Wsymm | W_Wtrans | W_wrefl | W_wsymm | W_wtrans
      | W_Wrefl
	-> raise FalseWitness
     )
  | _ ->
      try
	check_hastype env (head_reduction env p) o t
      with
	Not_found -> err env (get_pos p) ("expected a witness expression: " ^ lf_expr_to_string env p)

and check_type_equality env p t t' =
  match unmark p with
  | APPLY(W wh, pargs) -> (
      match wh with
      | W_weleq ->
	  let peq = args1 pargs in
	  let o,p = unpack_El' t in
	  let o',p' = unpack_El' t' in
	  check_object_equality env peq o o' uuu;
	  check_hastype env p o uuu;
	  check_hastype env p' o' uuu
      | W_wrefl | W_Wrefl | W_Wsymm | W_Wtrans | W_wsymm | W_wtrans | W_wconv
      | W_wconveq | W_wpi1 | W_wpi2 | W_wlam | W_wl1 | W_wl2 | W_wev
      | W_wevt1 | W_wevt2 | W_wevf | W_wevo | W_wbeta | W_weta
	-> raise FalseWitness
     )
  | _ -> err env (get_pos p) ("expected a witness expression :  " ^ lf_expr_to_string env p)


and check_object_equality env p o o' t =
  match unmark p with
  | APPLY(W wh, pargs) -> (
      match wh with
      | W_wbeta ->
	  let p1,p2 = args2 pargs in
	  let f,o1,t1',t2 = unpack_ev' o in
	  let t1,o2 = unpack_lambda' f in
	  if not (term_equiv t1 t1') then mismatch_term env (get_pos t1) t1 (get_pos t1') t1';
	  check_hastype env p1 o1 t1;
	  let env,p2',o2',t2' = open_context t1 (env,p2,o2,t2) in
	  check_hastype env p2' o2' t2';
	  let t2'' = apply_2 1 t2 o1 p1 in
	  if not (term_equiv t2'' t) then mismatch_term env (get_pos t2'') t2'' (get_pos t) t;
	  let o2' = apply_2 1 o2 o1 p1 in
	  if not (term_equiv o2' o') then mismatch_term env (get_pos o2') o2' (get_pos o') o'
      | W_wrefl -> (
	  let p,p' = args2 pargs in
	  check_hastype env p o t;
	  check_hastype env p' o' t;
	  if not (term_equiv o o') then mismatch_term env (get_pos o) o (get_pos o') o';
	 )
      | _ -> raise FalseWitness)
  | _ -> raise FalseWitness

let check (env:environment) (t:lf_type) =
  try
    match unmark t with
    | F_Apply(F_istype,[t]) -> check_istype env t
    | F_Apply(F_witnessed_istype,[w;t]) -> raise NotImplemented
    | F_Apply(F_witnessed_hastype,[w;o;t]) -> check_hastype env w o t
    | F_Apply(F_witnessed_type_equality,[w;t;t']) -> check_type_equality env w t t'
    | F_Apply(F_witnessed_object_equality,[w;o;o';t]) -> check_object_equality env w o o' t
    | _ -> err env (get_pos t) "expected a witnessed judgment"
  with
    FalseWitness -> err env (get_pos t) "incorrect witness"

(** Subordination *)

exception IncomparableKinds of lf_kind * lf_kind

let min_kind k l =
  match compare_kinds k l with
  | K_equal | K_less -> k
  | K_greater -> l
  | K_incomparable -> raise (IncomparableKinds (k,l))

let min_kind_option k l =
  match k,l with
  | None,None -> None
  | k,None -> k
  | None,l -> l
  | Some k, Some l -> Some (min_kind k l)

let rec min_type_kind t =
  match unmark t with
  | F_Singleton(x,t) -> min_type_kind t
  | F_Pi(v,t,u) -> min_type_kind u
  | F_Apply(h,args) -> ultimate_kind (tfhead_to_kind h)
  | F_Sigma(v,t,u) -> min_kind (min_type_kind t) (min_type_kind u)

let rec min_target_kind t =
  match unmark t with
  | F_Singleton (e,t) -> min_target_kind t
  | F_Pi(v,t,u) -> min_target_kind u
  | F_Apply(h,args) -> Some (ultimate_kind (tfhead_to_kind h))
  | F_Sigma(v,t,u) -> min_kind_option (min_target_kind t) (min_target_kind u)

(** Type checking and term_equiv routines. *)

let rec term_equivalence (env:environment) (x:lf_expr) (y:lf_expr) (t:lf_type) : unit =
  (* assume x and y have already been verified to be of type t *)
  (* see figure 11, page 711 [EEST] *)
  if !debug_mode then printf " term_equiv\n\t x=%a\n\t y=%a\n\t t=%a\n%!" _e (env,x) _e (env,y) _t (env,t);
  (if try_alpha && term_equiv x y then () else
  match unmark t with
  | F_Singleton _ -> ()
  | F_Sigma (v,a,b) ->
      term_equivalence env (pi1 x) (pi1 y) a;
      term_equivalence env (pi2 x) (pi2 y) (subst_type (pi1 x) b)
  | F_Pi (v,a,b) ->
      let env = local_lf_bind env v a in
      let v = var_to_lf (VarRel 0) in
      let xres = apply_args (rel_shift_expr 1 x) (ARG(v,END)) in
      let yres = apply_args (rel_shift_expr 1 y) (ARG(v,END)) in
      term_equivalence env xres yres b
  | F_Apply(j,args) ->
      if j == F_uexp then (
	if !debug_mode then printf "warning: ulevel comparison judged true: %a = %a\n%!" _e (env,x) _e (env,y);
       )
      else (
	let x = head_normalization env x in
	let y = head_normalization env y in
	if !debug_mode then printf "\t new x=%a\n\t new y=%a\n%!" _e (env,x) _e (env,y);
	let t' = path_equivalence env x y in
	if !debug_mode then printf "\t new t'=%a\n\n%!" _t (env,t');
	subtype env t' t			(* this was not spelled out in the paper, which concerned base types only *)
	  ));
  if !debug_mode then printf " term_equiv okay\n%!"

and path_equivalence (env:environment) (x:lf_expr) (y:lf_expr) : lf_type =
  (* assume x and y are head reduced *)
  (* see figure 11, page 711 [EEST] *)
  if !debug_mode then printf " path_equivalence\n\t x=%a\n\t y=%a\n%!" _e (env,x) _e (env,y);
  let t =
  (
  match x,y with
  | (xpos,APPLY(head,args)), (ypos,APPLY(head',args')) -> (
      if head <> head' then raise TermEquivalenceFailure;
      let t = head_to_type env xpos head in
      let rec repeat t args_passed args args' =
	if !debug_mode then printf " path_equivalence repeat, head type = %a, args_passed = %a\n\targs = %a\n\targs' = %a\n%!" _t (env,t) _s args_passed _s args _s args';
        match t,args,args' with
        | (pos,F_Pi(v,a,b)), ARG(x,args), ARG(y,args') ->
            term_equivalence env x y a;
	    let b' = subst_type x b in
            repeat b' (ARG(x,args_passed)) args args'
        | (pos,F_Sigma(v,a,b)), CAR args, CAR args' ->
	    let args_passed' = CAR args_passed in
	    repeat a args_passed' args args'
        | (pos,F_Sigma(v,a,b)), CDR args, CDR args' ->
	    let b' = subst_car_passed_term pos head args_passed b in
	    let args_passed' = CDR args_passed in
	    repeat b' args_passed' args args'
        | t, END, END -> t
        | _ ->
	    if !debug_mode then printf " path_equivalence failure\n%!";
	    raise TermEquivalenceFailure
      in repeat t END args args')
  | _  ->
      if !debug_mode then printf " path_equivalence failure\n%!";
      raise TermEquivalenceFailure) in
  if !debug_mode then printf " path_equivalence okay, type = %a\n%!" _t (env,t);
  t

and type_equivalence (env:environment) (t:lf_type) (u:lf_type) : unit =
  (* see figure 11, page 711 [EEST] *)
  (* assume t and u have already been verified to be types *)
  if !debug_mode then printf " type_equivalence\n\t t=%a\n\t u=%a\n%!" _t (env,t) _t (env,u);
  if try_alpha && type_equiv t u then () else
  let (tpos,t0) = t in
  let (upos,u0) = u in
  try
    match t0, u0 with
    | F_Singleton a, F_Singleton b ->
        let (x,t) = strip_singleton a in
        let (y,u) = strip_singleton b in
        type_equivalence env t u;
        term_equivalence env x y t
    | F_Sigma(v,a,b), F_Sigma(w,c,d)
    | F_Pi(v,a,b), F_Pi(w,c,d) ->
        type_equivalence env a c;
        let env = local_lf_bind env v a in
        type_equivalence env b d
    | F_Apply(h,args), F_Apply(h',args') ->
        (* Here we augment the algorithm in the paper to handle the type families of LF. *)
        if not (h = h') then raise TypeEquivalenceFailure;
        let k = tfhead_to_kind h in
        let rec repeat (k:lf_kind) args args' : unit =
          match k,args,args' with
          | K_Pi(v,t,k), x :: args, x' :: args' ->
              term_equivalence env x x' t;
              repeat (subst_kind x k) args args'
          | ( K_expression | K_judgment | K_primitive_judgment | K_judged_expression ), [], [] -> ()
          | _ -> (trap(); raise Internal)
        in repeat k args args'
    | _ -> raise TypeEquivalenceFailure
  with TermEquivalenceFailure -> raise TypeEquivalenceFailure

and subtype (env:environment) (t:lf_type) (u:lf_type) : unit =
  (* assume t and u have already been verified to be types *)
  (* driven by syntax *)
  (* see figure 12, page 715 [EEST] *)
  if !debug_mode then printf " subtype\n\t t=%a\n\t u=%a\n%!" _t (env,t) _t (env,u);
  let (tpos,t0) = t in
  let (upos,u0) = u in
  try
    match t0, u0 with
    | F_Singleton a, F_Singleton b ->
        let (x,t) = strip_singleton a in
        let (y,u) = strip_singleton b in
        type_equivalence env t u;
        term_equivalence env x y t
    | _, F_Singleton _ -> raise SubtypeFailure
    | F_Singleton a, _ ->
        let (x,t) = strip_singleton a in
        subtype env t u
    | F_Pi(x,a,b) , F_Pi(y,c,d) ->
        subtype env c a;                        (* contravariant *)
        subtype (local_lf_bind env x c) b d
    | F_Sigma(x,a,b) , F_Sigma(y,c,d) ->
        subtype env a c;                        (* covariant *)
        subtype (local_lf_bind env x a) b d
    | F_Apply(F_istype_witness,_), F_Apply(F_wexp,[])
    | F_Apply(F_hastype_witness,_), F_Apply(F_wexp,[])
    | F_Apply(F_type_equality_witness,_), F_Apply(F_wexp,[])
    | F_Apply(F_object_equality_witness,_), F_Apply(F_wexp,[]) -> ()
    | _ -> type_equivalence env (tpos,t0) (upos,u0)
  with TypeEquivalenceFailure -> raise SubtypeFailure

let is_subtype (env:environment) (t:lf_type) (u:lf_type) : bool =
  try subtype env t u; true
  with SubtypeFailure -> false

let rec is_product_type env t =
  match unmark t with
  | F_Pi _ -> true
  | F_Singleton(_,t) -> is_product_type env t
  | F_Sigma _ | F_Apply _ -> false

(** Type checking routines *)

let rec type_check (surr:surrounding) (env:environment) (e0:lf_expr) (t:lf_type) : lf_expr =
  (* assume t has been verified to be a type *)
  (* see figure 13, page 716 [EEST] *)
  (* we modify the algorithm to return a possibly modified expression e, with holes filled in by tactics *)
  let pos = get_pos t in
  match unmark e0, unmark t with
  | APPLY(TAC tac,args), _ -> (
      let pos = get_pos e0 in
      match show_tactic_result env (apply_tactic surr env pos t args tac) with
      | TacticSuccess suggestion -> type_check surr env suggestion t
      | TacticFailure -> (* we may want the tactic itself to raise the error message, when tactics are chained *)
          raise (TypeCheckingFailure (env, surr, [
                               pos, "tactic failed: "^ lf_expr_to_string env e0;
                               pos, "in hole of type\n\t"^lf_type_to_string env t])))

  | LAMBDA(v,body), F_Pi(w,a,b) -> (* the published algorithm is not applicable here, since
                                   our lambda doesn't contain type information for the variable,
                                   and theirs does *)
      let surr = (env,S_body,Some e0,Some t) :: surr in
      let body = type_check surr (local_lf_bind env v a) body b in
      pos, LAMBDA(v,body)
  | LAMBDA _, F_Sigma _ ->
      raise (TypeCheckingFailure (env, surr, [
				  get_pos e0, "error: expected a pair but got a function:\n\t" ^ lf_expr_to_string env e0]))
  | LAMBDA _, _ ->
      (* we don't have singleton kinds, so if t is definitionally equal to a product type, it already looks like one *)
      raise (TypeCheckingFailure (env, surr, [
				  get_pos t, "error: expected something of type\n\t" ^ lf_type_to_string env t;
				  get_pos e0, "but got a function\n\t" ^ lf_expr_to_string env e0]))
  | _, F_Sigma(w,a,b) -> (* The published algorithm omits this, correctly, but we want to
                            give advice to tactics for filling holes in [p], so we try type-directed
                            type checking as long as possible. *)
      let (x,y) = (pi1 e0,pi2 e0) in
      let x = type_check ((env,S_projection 1,Some e0,Some t) :: surr) env x a in
      let b = subst_type x b in
      let y = type_check ((env,S_projection 2,Some e0,Some t) :: surr) env y b in
      pos, CONS(x,y)

  | _, F_Apply(F_istype_witness, [t]) -> raise NotImplemented
  | _, F_Apply(F_hastype_witness, [o;t]) -> check_hastype env e0 o t; e0 (* should apply possible tactics somehow here *)
  | _, F_Apply(F_type_equality_witness,[t;t']) -> check_type_equality env e0 t t'; e0
  | _, F_Apply(F_object_equality_witness,[o;o';t]) -> check_object_equality env e0 o o' t; e0

  | _, _  ->
      let (e,s) = type_synthesis surr env e0 in
      if !debug_mode then printf " type_check\n\t e = %a\n\t s = %a\n\t t = %a\n%!" _e (env,e) _t (env,s) _t (env,t);
      try
        subtype env s t;
        e
      with SubtypeFailure -> 
	mismatch_term_type_type env e0 (un_singleton s) t

and type_synthesis (surr:surrounding) (env:environment) (m:lf_expr) : lf_expr * lf_type =
  (* assume nothing *)
  (* see figure 13, page 716 [EEST] *)
  (* return a pair consisting of the original expression with any tactic holes filled in,
     and the synthesized type *)
  let pos = get_pos m in
  match unmark m with
  | LAMBDA _ -> err env pos ("function has no type: " ^ lf_expr_to_string env m)
  | CONS(x,y) ->
      let x',t = type_synthesis surr env x in
      let y',u = type_synthesis surr env y in (pos,CONS(x',y')), (pos,F_Sigma(id "_",t,u))
  | APPLY(head,args) ->
      match head with
      | TAC _ -> err env pos "tactic found in context where no type advice is available"
      | _ -> ();
      let head_type =
	try
	  head_to_type env pos head 
	with Failure "nth" ->
	  printf "%a: head = %a, args = %a\n%!" _pos pos _h head _s args;
	  print_context None stdout env;
	  raise Internal
      in
      let args_passed = END in            (* we retain the arguments we've passed as a spine in reverse order *)
      let rec repeat i env head_type args_passed args = (
        match unmark head_type, args with
        | F_Pi(v,a',a''), ARG(m',args') ->
            let surr = (env,S_argument i,Some m,None) :: surr in
            let env = apply_ts_binder env i m in
            let m' = type_check surr env m' a' in
	    if !debug_mode then (
	      printf " type_synthesis repeat\n head= %a, i=%d, head_type=%a, args_passed=%a, args=%a\n%!" _h head i _t (env,head_type) _s args_passed _s args;
	      printf "      a'=%a a''=%a m'=%a\n%!" _t (env,a') _t (env,a'') _e (env,m');
	     );
            let (args'',u) = repeat (i+1) env (subst_type m' a'') (ARG(m',args_passed)) args' in
            ARG(m',args''), u
        | F_Singleton(e,t), args -> repeat i env t args_passed args
        | F_Sigma(v,a,b), CAR args ->
            let (args',t) = repeat (i+1) env a (CAR args_passed) args in
            (CAR args', t)
        | F_Sigma(v,a,b), CDR args ->
            let b' = subst_car_passed_term pos head args_passed b in
            let (args',t) = repeat (i+1) env b' (CDR args_passed) args in
            (CDR args', t)
        | t, END -> END, (pos,t)
        | _, ARG(arg,_) ->
	    printf "%a: head= %a, args_passed= %a, args= %a\n%!" _pos pos _h head _s args_passed _s args;
	    err env (get_pos arg) "extra argument"
        | _, CAR _ -> err env pos ("pi1 expected a pair (3) but got " ^ lf_expr_to_string env (with_pos pos (APPLY(head,reverse_spine args_passed))))
        | _, CDR _ -> err env pos "pi2 expected a pair (3)"
       )
      in
      let (args',t) = repeat 0 env head_type args_passed args in
      let e = pos, APPLY(head,args') in
      let t = with_pos_of t (F_Singleton(e,t)) in (* this isn't quite like the algorithm in the paper, but it seems to work *)
      e,t

exception InsubordinateKinds of lf_kind * lf_kind

let rec check_less_equal t u =
  match min_target_kind u with
  | None -> ()
  | Some l ->
      let rec repeat t =
	match unmark t with
	| F_Singleton(e,t) -> repeat t
	| F_Pi(v,t,u) -> repeat t ; repeat u
	| F_Apply(h,args) ->
	    let k = ultimate_kind (tfhead_to_kind h) in
	    (
	     match compare_kinds k l with
	     | K_incomparable | K_greater -> raise (InsubordinateKinds(k,l))
	     | K_equal | K_less -> ())
	| F_Sigma(v,t1,t2) -> check_less_equal t1 u; check_less_equal t2 u
      in
      repeat t

let type_validity (surr:surrounding) (env:environment) (t:lf_type) : lf_type =
  (* assume the kinds of constants, and the types in them, have been checked *)
  (* driven by syntax *)
  (* return the same type t, but with tactic holes replaced *)
  (* see figure 12, page 715 [EEST] *)
  let rec type_validity surr env t =
    let t0 = t in
    let (pos,t) = t
    in
    ( pos,
      match t with
      | F_Pi(v,t,u) ->
          let t = type_validity ((env,S_argument 1,None,Some t0) :: surr) env t in
          let u = type_validity ((env,S_argument 2,None,Some t0) :: surr) (local_lf_bind env v t) u in (
	  try
	    check_less_equal t u
	  with
	  | InsubordinateKinds(k,l) | IncomparableKinds(k,l) ->
	      raise (TypeCheckingFailure
		       (env, [], [
			get_pos t, "expected type of kind involving \"" ^ lf_kind_to_string env k ^ "\"";
			get_pos u, "to be subordinate to type of kind involving \"" ^ lf_kind_to_string env l ^ "\""])));
          F_Pi(v,t,u)
      | F_Sigma(v,t,u) ->
          let t = type_validity ((env,S_argument 1,None,Some t0) :: surr) env t in
          let u = type_validity ((env,S_argument 2,None,Some t0) :: surr) (local_lf_bind env v t) u in
          F_Sigma(v,t,u)
      | F_Apply(head,args) ->
          let kind =
	    try tfhead_to_kind head
	    with UndeclaredTypeConstant(pos,name) -> err env pos ("undeclared type constant: " ^ name)
	  in
          let rec repeat i env kind (args:lf_expr list) =
            match kind, args with
            | ( K_ulevel | K_primitive_judgment | K_expression | K_judgment | K_witnessed_judgment | K_judged_expression ), [] -> []
            | ( K_ulevel | K_primitive_judgment | K_expression | K_judgment | K_witnessed_judgment | K_judged_expression ), x :: args -> err env pos "at least one argument too many";
            | K_Pi(v,a,kind'), x :: args ->
                let x' = type_check ((env,S_argument i,None,Some t0) :: surr) env x a in
                x' :: repeat (i+1) env (subst_kind x' kind') args
            | K_Pi(_,a,_), [] -> errmissingarg env pos a
          in
          let args' = repeat 1 env kind args in
          F_Apply(head,args')
      | F_Singleton(x,t) ->
          let t = type_validity ((env,S_argument 2,None,Some t0) :: surr) env t in
          let x = type_check ((env,S_argument 1,None,Some t0) :: surr) env x t in                (* rule 46 *)
          F_Singleton(x,t)
     ) in
  type_validity surr env t

let type_synthesis = type_synthesis []

(** Normalization routines. *)

(* We may wish to put the normalization routines in another file. *)

let rec num_args t = match unmark t with
  | F_Pi(_,_,b) -> 1 + num_args b
  | _ -> 0

let term_normalization_ctr = new_counter()

let rec term_normalization (env:environment) (x:lf_expr) (t:lf_type) : lf_expr =
  (* see figure 9 page 696 [EEST] *)
  let (pos,t0) = t in
  match t0 with
  | F_Pi(v,a,b) ->
      let c = term_normalization_ctr() in
      let env = local_lf_bind env v a in
      if !debug_mode then printf "term_normalization(%d) x = %a\n%!" c _e (env,x);
      let result =
	match unmark x with
	| LAMBDA(_,body) -> body	(* this is just an optimization *)
	| _ -> apply_args (rel_shift_expr 1 x) (ARG(var_to_lf (VarRel 0),END)) in
      let body = term_normalization env result b in
      let r = pos, LAMBDA(v,body) in
      if !debug_mode then printf "term_normalization(%d) r = %a\n%!" c _e (env,result);
      r
  | F_Sigma(v,a,b) ->
      let pos = get_pos x in
      let p = x in
      let x = pi1 p in
      let y = pi2 p in
      let x = term_normalization env x a in
      let b = subst_type x b in
      let y = term_normalization env y b in
      pos, CONS(x,y)
  | F_Apply _ ->
      let x = head_normalization env x in
      let (x,t) = path_normalization env x in
      x
  | F_Singleton(x',t) -> term_normalization env x t

and path_normalization (env:environment) (x:lf_expr) : lf_expr * lf_type =
  (* returns the normalized term x and the inferred type of x *)
  (* see figure 9 page 696 [EEST] *)
  (* assume x is head normalized *)
  if !debug_mode then printf " path_normalization entering with x=%a\n%!" _e (env,x);
  let pos = get_pos x in
  match unmark x with
  | LAMBDA _ -> err env pos "path_normalization encountered a function"
  | CONS _ -> err env pos "path_normalization encountered a pair"
  | APPLY(head,args) -> (
      if !debug_mode then printf "\thead=%a args=%a\n%!" _h head _s args;
      let t0 = head_to_type env pos head in
      let (t,args) =
        let args_passed = END in          (* we store the arguments we've passed in reverse order *)
        let rec repeat t args_passed args : lf_type * spine = (
	  if !debug_mode then printf " path_normalization repeat\n\tt=%a\n\targs_passed=%a\n\targs=%a\n%!" _e (env,x) _s args_passed _s args;
          match unmark t with
          | F_Pi(v,a,b) -> (
              match args with
              | END -> raise (TypeCheckingFailure (env, [], [
                                                    pos , "expected "^string_of_int (num_args t)^" more argument"^if num_args t > 1 then "s" else "";
                                                    (get_pos t0), (" using:\n\t"^lf_head_to_string head^" : "^lf_type_to_string env t0)]))
              | CAR args -> err env pos "pi1 expected a pair (4)"
              | CDR args -> err env pos "pi2 expected a pair (4)"
              | ARG(x, args) ->
                  let b = subst_type x b in
                  let x = term_normalization env x a in
                  let (c,args) = repeat b (ARG(x,args_passed)) args in
                  (c, ARG(x,args)))
          | F_Singleton _ ->
	      if !debug_mode then printf "\tbad type t = %a\n%!" _t (env,t);
	      print_context (Some 5) stdout env;
	      (trap(); raise Internal) (* x was head normalized, so any definition of head should have been unfolded *)
          | F_Sigma(v,a,b) -> (
              match args with
              | END -> (t,END)
              | CAR args ->
                  let (c,args) = repeat a (CAR args_passed) args in
                  (c, CAR args)
              | CDR args ->
                  let b = subst_car_passed_term pos head args_passed b in
                  let (c,args) = repeat b (CDR args_passed) args in
                  (c, CDR args)
              | ARG(x,_) -> err env (get_pos x) "unexpected argument")
          | F_Apply _ -> (
              match args with
              | END -> (t,END)
              | CAR args -> err env pos "pi1 expected a pair (5)"
              | CDR args -> err env pos "pi2 expected a pair (5)"
              | ARG(x,args) -> err env (get_pos x) "unexpected argument")
	 ) in
	repeat t0 args_passed args in
      ((pos,APPLY(head,args)), t))

let rec type_normalization (env:environment) (t:lf_type) : lf_type =
  (* see figure 9 page 696 [EEST] *)
  let (pos,t0) = t in
  let t = match t0 with
  | F_Pi(v,a,b) ->
      let a' = type_normalization env a in
      let b' = type_normalization (local_lf_bind env v a) b in
      F_Pi(v,a',b')
  | F_Sigma(v,a,b) ->
      let a' = type_normalization env a in
      let b' = type_normalization (local_lf_bind env v a) b in
      F_Sigma(v,a',b')
  | F_Apply(head,args) ->
      let kind = tfhead_to_kind head in
      let args =
        let rec repeat env kind (args:lf_expr list) =
          match kind, args with
          | ( K_ulevel | K_primitive_judgment | K_expression | K_judgment | K_witnessed_judgment | K_judged_expression ), [] -> []
          | ( K_ulevel | K_primitive_judgment | K_expression | K_judgment | K_witnessed_judgment | K_judged_expression ), x :: args -> err env pos "too many arguments"
          | K_Pi(v,a,kind'), x :: args ->
              term_normalization env x a ::
              repeat env (subst_kind x kind') args
          | K_Pi(_,a,_), [] -> errmissingarg env pos a
        in repeat env kind args
      in F_Apply(head,args)
  | F_Singleton(x,t) ->
      F_Singleton( term_normalization env x t, type_normalization env t )
  in (pos,t)

(*
  Local Variables:
  compile-command: "make -C .. src/lfcheck.cmo "
  End:
 *)
