(** Implement the binary equivalence algorithms from sections 5 and 6 of the paper:

    [EEST]: Extensional Equivalence and Singleton Types
    by Christopher A. Stone and Robert Harper
    ACM Transactions on Computational Logic, Vol. 7, No. 4, October 2006, Pages 676-722.
*)

(*

  We probably don't handle types such as [Pi x:A, Singleton(B)] well.

*)

open Error
open Variables
open Typesystem
open Names
open Printer
open Substitute
open Printf
open Helpers
open Tau

exception TermEquivalenceFailure
exception TypeEquivalenceFailure
exception SubtypeFailure

let abstraction1 (env:context) = function
  | ARG(t,ARG((_,LAMBDA(x, _)),_)) -> ts_bind (x,t) env
  | _ -> env

let abstraction2 (env:context) = function
  | ARG(_,ARG(_,ARG(n,ARG((_,LAMBDA(x,_)),_)))) -> ts_bind (x,(get_pos n, make_T_El n)) env
  | _ -> env

let abstraction3 (env:context) = function
  | ARG(f,ARG(_,ARG((_,LAMBDA(x, _)),_))) -> 
      let tf = tau env f in (
      match unmark tf with
      | APPLY(T T_Pi, ARG(t, _)) -> ts_bind (x,t) env
      | _ -> env)
  | _ -> env

let ts_binders = [
  ((O O_lambda, 1), abstraction1);
  ((T T_Pi, 1), abstraction1);
  ((T T_Sigma, 1), abstraction1);
  ((O O_forall, 3), abstraction2);
  ((O O_ev, 2), abstraction3)
]

let apply_ts_binder env i e =
  match unmark e with
  | APPLY(h,args) -> (
      try
        (List.assoc (h,i) ts_binders) env args
      with
        Not_found -> env)
  | _ -> raise Internal

let try_alpha = false (* turning this on could slow things down a lot before we implement hash codes *)

let err env pos msg = raise (TypeCheckingFailure (env, [pos, msg]))

let errmissingarg env pos a = err env pos ("missing next argument, of type "^lf_type_to_string a)

let mismatch_type env pos t pos' t' = 
  raise (TypeCheckingFailure (env, [
         pos , "expected type " ^ lf_type_to_string t;
         pos', "to match      " ^ lf_type_to_string t']))

let mismatch_term_type env e s t =
  raise (TypeCheckingFailure (env, [
               get_pos e, "expected term\n\t" ^ lf_expr_to_string e;
               get_pos s, "of type\n\t" ^ lf_type_to_string s;
               get_pos t, "to be compatible with type\n\t" ^ lf_type_to_string t]))


let mismatch_term_t env pos x pos' x' t = 
  raise (TypeCheckingFailure (env, [
                    pos , "expected term\n\t" ^ lf_expr_to_string x ;
                    pos',      "to match\n\t" ^ lf_expr_to_string x';
               get_pos t,       "of type\n\t" ^ lf_type_to_string t]))

let mismatch_term env pos x pos' x' = 
  raise (TypeCheckingFailure (env, [
                    pos , "expected term\n\t" ^ lf_expr_to_string x;
                    pos',      "to match\n\t" ^ lf_expr_to_string x']))

let function_expected env f t =
  raise (TypeCheckingFailure (env, [
                    get_pos f, "encountered a non-function\n\t" ^ lf_expr_to_string f;
                    get_pos t, "of type\n\t" ^ lf_type_to_string t]))

let rec strip_singleton ((_,(_,t)) as u) = match t with
| F_Singleton a -> strip_singleton a
| _ -> u

(* background assumption: all types in the environment have been verified *)

let apply_tactic surr env pos t = function
  | Tactic_hole n -> TacticFailure
  | Tactic_name name ->
      let tactic = 
        try List.assoc name !tactics
        with Not_found -> err env pos ("unknown tactic: " ^ name) in
      tactic surr env pos t
  | Tactic_index n ->
      let (v,u) = 
        try List.nth env n 
        with Failure nth -> err env pos ("index out of range: "^string_of_int n) in
      TacticSuccess (var_to_lf_pos pos v)

let rec natural_type (env:context) (x:lf_expr) : lf_type =
  if true then raise Internal;          (* this function is unused, because "unfold" below does what we need for weak head reduction *)
  (* assume nothing *)
  (* see figure 9 page 696 [EEST] *)
  let pos = get_pos x in 
  match unmark x with
  | APPLY(l,args) -> 
      let t = label_to_type env pos l in
      let rec repeat i args t =
        match args, unmark t with
        | ARG(x,args), F_Pi(v,a,b) -> repeat (i+1) args (subst_type (v,x) b)
        | ARG _, _ -> err env pos "at least one argument too many"
        | CAR args, F_Sigma(v,a,b) -> repeat (i+1) args a
        | CAR _, _ -> err env pos "pi1 expected a pair"
        | CDR args, F_Sigma(v,a,b) -> repeat (i+1) args b
        | CDR _, _ -> err env pos "pi2 expected a pair"
        | END, F_Pi(v,a,b) -> errmissingarg env pos a
        | END, t -> t
      in nowhere 5 (repeat 0 args t)
  | LAMBDA _ -> err env pos "LF lambda expression found, has no natural type"
  | CONS _ -> err env pos "LF pair found, has no natural type"

let unfold env v =
  match unmark( lookup_type env v ) with
  | F_Singleton a -> let (x,t) = strip_singleton a in x
  | _ -> raise Not_found                (* What if the type is effectively a singleton, such as Sing(x)*Sing(y) ? *)

let rec head_reduction (env:context) (x:lf_expr) : lf_expr =
  (* assume nothing *)
  (* see figure 9 page 696 [EEST] *)
  (* may raise Not_found if there is no head reduction *)
  let pos = get_pos x in
  match unmark x with
  | APPLY(h,args) -> (
      match h with
      | V v -> let f = unfold env v in apply_args f args
      | FUN(f,t) -> (
          try
            let f = head_reduction env f in with_pos pos (APPLY(FUN(f,t),args))
          with Not_found ->
            apply_args f args)
      | TAC _ -> raise Internal
      | (O _|T _|U _) -> raise Not_found)
  | CONS _ | LAMBDA _ -> raise Not_found

let rec head_normalization (env:context) (x:lf_expr) : lf_expr =
  (* see figure 9 page 696 [EEST] *)
  try head_normalization env (head_reduction env x)
  with Not_found -> x

(** Type checking and equivalence routines. *)

let rec term_equivalence (xpos:position) (ypos:position) (env:context) (x:lf_expr) (y:lf_expr) (t:lf_type) : unit =
  (* assume x and y have already been verified to be of type t *)
  (* see figure 11, page 711 [EEST] *)
  if try_alpha && Alpha.UEqual.term_equiv empty_uContext x y then () else
  match unmark t with
  | F_Singleton _ -> ()
  | F_Sigma (v,a,b) -> raise NotImplemented
  | F_Pi (v,a,b) -> (
      match unmark x, unmark y with
      | LAMBDA(t,x), LAMBDA(u,y) ->
          let w = newfresh (Var "v") in
          term_equivalence xpos ypos 
            ((w,a) :: env)
            (subst (t,var_to_lf w) x)   (* with deBruijn indices, this will go away *)
            (subst (u,var_to_lf w) y) 
            (subst_type (v,var_to_lf w) b)
      | _ -> raise Internal)
  | F_APPLY(j,args) ->
      let x = head_normalization env x in
      let y = head_normalization env y in
      let t' = path_equivalence env x y in
      type_equivalence env t t'

and path_equivalence (env:context) (x:lf_expr) (y:lf_expr) : lf_type =
  (* assume x and y are head reduced *)
  (* see figure 11, page 711 [EEST] *)
  match x,y with
  | (xpos,APPLY(f,args)), (ypos,APPLY(f',args')) -> (
      if not (f = f') then raise TermEquivalenceFailure;
      let t = label_to_type env xpos f in
      let rec repeat t args args' =
        match t,args,args' with
        | t, END, END -> t
        | (pos,F_Sigma(v,a,b)), CAR args, CAR args' ->
            repeat a args args'
        | (pos,F_Sigma(v,a,b)), CDR args, CDR args' ->
            repeat (subst_type (v,x) b) args args'
        | (pos,F_Pi(v,a,b)), ARG(x,args), ARG(y,args') ->
            term_equivalence xpos ypos env x y a;
            repeat (subst_type (v,x) b) args args'
        | _ -> raise TermEquivalenceFailure
      in repeat t args args')
  | _  -> raise TermEquivalenceFailure

and type_equivalence (env:context) (t:lf_type) (u:lf_type) : unit =
  (* see figure 11, page 711 [EEST] *)
  (* assume t and u have already been verified to be types *)
  if try_alpha && Alpha.UEqual.type_equiv empty_uContext t u then () else
  let (tpos,t0) = t in 
  let (upos,u0) = u in 
  try
    match t0, u0 with
    | F_Singleton a, F_Singleton b ->
        let (x,t) = strip_singleton a in
        let (y,u) = strip_singleton b in
        type_equivalence env t u;
        term_equivalence tpos upos env x y t
    | F_Sigma(v,a,b), F_Sigma(w,c,d)
    | F_Pi(v,a,b), F_Pi(w,c,d) ->
        type_equivalence env a c;
        let x = newfresh v in
        let b = subst_type (v, var_to_lf x) b in
        let d = subst_type (w, var_to_lf x) d in
        let env = (x, a) :: env in
        type_equivalence env b d
    | F_APPLY(h,args), F_APPLY(h',args') ->
        (* Here we augment the algorithm in the paper to handle the type families of LF. *)
        if not (h = h') then raise TypeEquivalenceFailure;
        let k = tfhead_to_kind h in
        let rec repeat (k:lf_kind) args args' : unit =
          match k,args,args' with
          | K_Pi(v,t,k), x :: args, x' :: args' ->
              term_equivalence tpos upos env x x' t;
              repeat (subst_kind (v,x) k) args args'
          | K_type, [], [] -> ()
          | _ -> raise Internal
        in repeat k args args'
    | _ -> raise TypeEquivalenceFailure
  with TermEquivalenceFailure -> raise TypeEquivalenceFailure

let rec subtype (env:context) (t:lf_type) (u:lf_type) : unit =
  (* assume t and u have already been verified to be types *)
  (* driven by syntax *)
  (* see figure 12, page 715 [EEST] *)
  let (tpos,t0) = t in 
  let (upos,u0) = u in 
  try
    match t0, u0 with
    | F_Singleton a, F_Singleton b ->
        let (x,t) = strip_singleton a in
        let (y,u) = strip_singleton b in
        type_equivalence env t u;
        term_equivalence tpos upos env x y t
    | _, F_Singleton _ -> raise SubtypeFailure
    | F_Singleton a, _ -> 
        let (x,t) = strip_singleton a in
        type_equivalence env t u
    | F_Pi(x,a,b) , F_Pi(y,c,d) ->
        subtype env c a;                        (* contravariant *)
        let w = newfresh (Var "w") in
        subtype ((w, c) :: env) (subst_type (x,var_to_lf w) b) (subst_type (y,var_to_lf w) d)
    | F_Sigma(x,a,b) , F_Sigma(y,c,d) ->
        subtype env a c;                        (* covariant *)
        let w = newfresh (Var "w") in
        subtype ((w, a) :: env) (subst_type (x,var_to_lf w) b) (subst_type (y,var_to_lf w) d)
    | _ -> type_equivalence env (tpos,t0) (upos,u0)
  with TypeEquivalenceFailure -> raise SubtypeFailure

let rec type_check (surr:surrounding) (env:context) (e0:lf_expr) (t:lf_type) : lf_expr = 
  (* assume t has been verified to be a type *)
  (* see figure 13, page 716 [EEST] *)
  (* we modify the algorithm to return a possibly modified expression e, with holes filled in by tactics *)
  (* We hard code one tactic:
       Fill in holes of the form [ ([ev] f o _) ] by using [tau] to compute the type that ought to go there. *)
  let pos = get_pos t in 
  match unmark e0, unmark t with
  | APPLY(TAC tac,args), _ -> (
      let pos = get_pos e0 in 
      match apply_tactic surr env pos t tac with
      | TacticSuccess suggestion -> 
          let suggestion = apply_args suggestion args in
          type_check surr env suggestion t
      | TacticFailure ->
          raise (TypeCheckingFailure (env, [
                               pos, "tactic failed : "^tactic_to_string tac;
                               pos, "in hole of type: "^lf_type_to_string t])))

  | LAMBDA(v,body), F_Pi(w,a,b) -> (* the published algorithm is not applicable here, since
                                   our lambda doesn't contain type information for the variable,
                                   and theirs does *)
      let surr = (None,e0,Some t) :: surr in
      let body = type_check surr ((v,a) :: env) body (subst_type (w,var_to_lf v) b) in
      pos, LAMBDA(v,body)
  | LAMBDA _, _ -> err env pos "did not expect a lambda expression here"
 
  | _, F_Sigma(w,a,b) -> (* The published algorithm omits this, correctly, but we want to
                            give advice to tactics for filling holes in [p], so we try type-directed
                            type checking as long as possible. *)
      let (x,y) = (pi1 e0,pi2 e0) in
      let x = type_check [(Some 0,e0,Some t)] env x a in
      let b = subst_type (w,x) b in
      let y = type_check [(Some 1,e0,Some t)] env y b in
      pos, CONS(x,y)

  | _, _  ->
      let (e,s) = type_synthesis surr env e0 in 
      try
        subtype env s t;
        e
      with SubtypeFailure -> mismatch_term_type env e0 s t

and type_synthesis (surr:surrounding) (env:context) (m:lf_expr) : lf_expr * lf_type =
  (* assume nothing *)
  (* see figure 13, page 716 [EEST] *)
  (* return a pair consisting of the original expression with any tactic holes filled in, 
     and the synthesized type *)
  let pos = get_pos m in
  match unmark m with
  | LAMBDA _ -> err env pos ("function has no type: "^lf_expr_to_string m)
  | CONS(x,y) ->
      let x',t = type_synthesis surr env x in
      let y',u = type_synthesis surr env y in (pos,CONS(x',y')), (pos,F_Sigma(newunused(),t,u))
  | APPLY(head,args) -> (
      match head with
      | TAC _ -> err env pos "tactic found in context where no type advice is available"
      | _ -> ();
      let head_type = label_to_type env pos head in
      let args_past = END in            (* we retain the arguments we've passed as a spine in reverse order *)
      let rec repeat i env head_type args_past args = (
        match unmark head_type, args with
        | F_Pi(v,a',a''), ARG(m',args') ->
            let surr = (Some i,m,None) :: surr in 
            let env = apply_ts_binder env i m in
            let m' = type_check surr env m' a' in
            let (args'',u) = repeat (i+1) env (subst_type (v,m') a'') (ARG(m',args_past)) args' in
            ARG(m',args''), u
        | F_Singleton(e,t), args -> repeat i env t args_past args
        | F_Sigma(v,a,b), CAR args ->
            let (args',t) = repeat (i+1) env a (CAR args_past) args in
            (CAR args', t)
        | F_Sigma(v,a,b), CDR args -> 
            let b = subst_type (v,with_pos pos (APPLY(head,reverse_spine (CAR args_past)))) b in 
            let (args',t) = repeat (i+1) env b (CDR args_past) args in
            (CDR args', t)
        | t, END -> END, (pos,t)
        | _, ARG(arg,_) -> err env (get_pos arg) "extra argument"
        | _, CAR _ -> err env pos "pi1 expected a pair"
        | _, CDR _ -> err env pos "pi2 expected a pair"
       )
      in
      let (args',t) = repeat 0 env head_type args_past args
      in (pos,APPLY(head,args')), t
     )

let type_validity (env:context) (t:lf_type) : lf_type =
  (* assume the kinds of constants, and the types in them, have been checked *)
  (* driven by syntax *)
  (* return the same type t, but with tactic holes replaced *)
  (* see figure 12, page 715 [EEST] *)
  let rec type_validity env t =
    let (pos,t) = t 
    in 
    ( pos,
      match t with 
      | F_Pi(v,t,u) ->
          let t = type_validity env t in
          let u = type_validity ((v,t) :: env) u in
          F_Pi(v,t,u)
      | F_Sigma(v,t,u) ->
          let t = type_validity env t in
          let u = type_validity ((v,t) :: env) u in
          F_Sigma(v,t,u)
      | F_APPLY(head,args) ->
          let kind = tfhead_to_kind head in
          let rec repeat env kind (args:lf_expr list) = 
            match kind, args with 
            | K_type, [] -> []
            | K_type, x :: args -> err env pos "at least one argument too many";
            | K_Pi(v,a,kind'), x :: args -> 
                let x' = type_check [] env x a in
                x' :: repeat ((v,a) :: env) kind' args
            | K_Pi(_,a,_), [] -> errmissingarg env pos a
          in 
          let args' = repeat env kind args in
          F_APPLY(head,args')
      | F_Singleton(x,t) -> 
          let t = type_validity env t in
          let x = type_check [] env x t in                (* rule 46 *)
          F_Singleton(x,t)) in
  try
    type_validity env t
  with TypeCheckingFailure(env,ps) ->
    raise (TypeCheckingFailure(
           env,
           ps @ [ (get_pos t, "while checking validity of type\n\t" ^ lf_type_to_string t) ]))

let type_synthesis = type_synthesis []

let type_check = type_check []


(** Normalization routines. *)

(* We may wish to put the normalization routines in another file. *)

let rec num_args t = match unmark t with 
  | F_Pi(_,_,b) -> 1 + num_args b
  | _ -> 0

let rec term_normalization (env:context) (x:lf_expr) (t:lf_type) : lf_expr =
  (* see figure 9 page 696 [EEST] *)
  let (pos,t0) = t in
  match t0 with 
  | F_Pi(v,a,b) -> (
      match unmark x with
      | LAMBDA(w,body) ->
          let b    = subst_type (v,var_to_lf w) b in
          let body = term_normalization ((w,a) :: env) body b in
          pos, LAMBDA(w,body)
      | _ -> raise Internal)
  | F_Sigma(v,a,b) ->
      let pos = get_pos x in
      let p = x in
      let x = pi1 p in
      let y = pi2 p in
      pos, CONS(
           term_normalization env x a,
           term_normalization env y (subst_type (v,x) b))
  | F_APPLY _
  | F_Singleton _ ->
      let x = head_normalization env x in
      let (x,t) = path_normalization env x in
      x
      
and path_normalization (env:context) (x:lf_expr) : lf_expr * lf_type =
  (* returns the normalized term x and the inferred type of x *)
  (* see figure 9 page 696 [EEST] *)
  (* assume x is head normalized *)
  let pos = get_pos x in
  match unmark x with
  | LAMBDA _ -> err env pos "path_normalization encountered a function"
  | CONS _ -> err env pos "path_normalization encountered a pair"
  | APPLY(head,args) -> (
      let t0 = label_to_type env pos head in
      let (t,args) =
        let args_past = END in          (* we store the arguments we've passed in reverse order *)
        let rec repeat t args_past args : lf_type * spine = (
          match unmark t with
          | F_Pi(v,a,b) -> (
              match args with
              | END -> raise (TypeCheckingFailure (env, [
                                                    pos , "expected "^string_of_int (num_args t)^" more arguments";
                                                    (get_pos t0), (" using:\n\t"^lf_head_to_string head^" : "^lf_type_to_string t0)]))
              | CAR args -> err env pos "pi1 expected a pair"
              | CDR args -> err env pos "pi2 expected a pair"
              | ARG(x, args) ->
                  let b = subst_type (v,x) b in
                  let x = term_normalization env x a in
                  let (c,args) = repeat b (ARG(x,args_past)) args in
                  (c, ARG(x,args)))
          | F_Singleton _ -> raise Internal (* x was head normalized, so any definition of head should have been unfolded *)
          | F_Sigma(v,a,b) -> (
              match args with 
              | END -> (t,END)
              | CAR args -> 
                  let (c,args) = repeat a (CAR args_past) args in
                  (c, CAR args)
              | CDR args -> 
                  let b = subst_type (v,with_pos pos (APPLY(head,reverse_spine (CAR args_past)))) b in
                  let (c,args) = repeat b (CDR args_past) args in
                  (c, CDR args)
              | ARG(x,_) -> err env (get_pos x) "unexpected argument")
          | F_APPLY _ -> (
              match args with
              | END -> (t,END)
              | CAR args -> err env pos "pi1 expected a pair"
              | CDR args -> err env pos "pi2 expected a pair"
              | ARG(x,args) -> err env (get_pos x) "unexpected argument"))
        in repeat t0 args_past args
      in ((pos,APPLY(head,args)), t))

let rec type_normalization (env:context) (t:lf_type) : lf_type =
  (* see figure 9 page 696 [EEST] *)
  let (pos,t0) = t in
  let t = match t0 with
  | F_Pi(v,a,b) -> 
      let a' = type_normalization env a in
      let b' = type_normalization ((v,a) :: env) b in
      F_Pi(v,a',b')
  | F_Sigma(v,a,b) -> 
      let a' = type_normalization env a in
      let b' = type_normalization ((v,a) :: env) b in
      F_Sigma(v,a',b')
  | F_APPLY(head,args) ->
      let kind = tfhead_to_kind head in
      let args =
        let rec repeat env kind (args:lf_expr list) = 
          match kind, args with 
          | K_type, [] -> []
          | K_type, x :: args -> err env pos "too many arguments"
          | K_Pi(v,a,kind'), x :: args ->
              term_normalization env x a ::
              repeat ((v,a) :: env) kind' args
          | K_Pi(_,a,_), [] -> errmissingarg env pos a
        in repeat env kind args
      in F_APPLY(head,args)
  | F_Singleton(x,t) -> 
      F_Singleton( term_normalization env x t, type_normalization env t )
  in (pos,t)

(* 
  Local Variables:
  compile-command: "ocamlbuild -cflags -g,-annot lfcheck.cmo "
  End:
 *)
