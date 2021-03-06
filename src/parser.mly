%{
open Typesystem
open Names
open Helpers
open Parse
open Printf
open Printer
open Error
%}
  (* this comment is accepted by menhir but not ocamlyacc *)
%start command ts_exprEof
%type <Toplevel.command> command
%type <Typesystem.judgment> judgment ts_judgment
%type <Typesystem.expr> expr ts_expr

(* for parsing a single expression *)
%type <Typesystem.expr> ts_exprEof

%token <int> NUMBER

%token <string> CONSTANT STRING NAME

%token

  LeftParen RightParen RightBracket LeftBracket Comma Colon Star Arrow
  ArrowFromBar Equal QuestionMark Axiom GreaterEqual Greater LessEqual Less
  Semicolon Ulevel Kumax Type Pi Lambda Sigma Check Show End Variable Alpha EOF
  Universes Tilde Singleton Dollar LF TS Kpair K_1 K_2 K_FST K_SND Times
  Turnstile DoubleArrow ColonColonEqual ColonEqual Theorem Goal LeftBrace
  RightBrace TurnstileDouble ColonColon Include Clear EqualEqual TTS Back
  BackTo Mode Period EndOfProofStepMarker Judgment

(* precedences, lowest first *)

%right

  Reduce_binder

%right

  Turnstile
  TurnstileDouble

%right

  ArrowFromBar			      (* TS notation for lambda *)
  DoubleArrow			      (* function type *)
  Arrow				      (* function type *)
  Times				      (* product type *)

%nonassoc

  Star					(* *x denotes @El[x] *)

%nonassoc

  Equal

%left

  LeftBracket				(* f[a] denotes substitution *)

%right

  (* These are the tokens that can begin a TS-expression, and
     thus might be involved in the decision about reducing an application: *)

  QuestionMark LeftParen Kumax CONSTANT Lambda Sigma Pi Dollar NAME

%nonassoc

  Reduce_application

  (* We want [f -> (f,END) -> (f)] unless there is another expr coming. *)

  (* In LF mode, we want [f x y z -> (f,x::END) y z -> (f,(y::x::END)) -> (f,(z::y::x::END)) -> (f x y z)] *)

%left

  K_1 K_2

%%

judgment:

    | t= unmarked_judgment
	{ Position($startpos, $endpos), t}

    | LeftParen t= judgment RightParen
	{ t }

unmarked_judgment:

    | f= judgment_constant args= expr*
	{ J_Basic(f,args) }

    | Pi v= identifier Colon a= judgment Comma b= judgment
	%prec Reduce_binder
	{ make_F_Pi a (v,b) }

    | Sigma v= identifier Colon a= judgment Comma b= judgment
	%prec Reduce_binder
    | LeftParen v= identifier Colon a= judgment RightParen Times b= judgment
	{ make_F_Sigma a (v,b) }

    | a= judgment Times b= judgment
	{ make_F_Sigma_simple a b }

    | LeftParen v= identifier Colon a= judgment RightParen Arrow b= judgment
       { make_F_Pi a (v,b) }

    | a= judgment Arrow b= judgment
       { unmark (a @-> b) }

    | Singleton LeftParen x= expr Colon t= judgment RightParen
	{ J_Singleton(x,t) }

    | LeftBracket t= expr Type RightBracket
	{ unmark (if !ts_mode then istype t else witnessed_istype t) }

    | LeftBracket a= expr Colon t= expr RightBracket
	{ unmark (hastype a t) }

    | LeftBracket a= expr EqualEqual b= expr Colon t= expr RightBracket
	{ unmark (object_equality a b t) }

    | LeftBracket t= expr EqualEqual u= expr RightBracket
	{ unmark (type_equality t u) }

    | LeftBracket t= expr Tilde u= expr Type RightBracket
	{ unmark (type_uequality t u) }

    | LeftBracket a= expr Tilde b= expr Colon t= expr RightBracket
	{ unmark (object_uequality a b t) }

    | a= judgment Turnstile b= judgment
    	{ let v = good_var_name a (id "foo") in (* the "|-" operator is not fully implemented yet *)
	  let v = get_pos a, v in
	  unmark (pi1_implication (v,a) b) }

    | v= marked_identifier Type
	{ let (pos,v) = v in make_F_Sigma texp (v,(if !ts_mode then istype_v else witnessed_istype_v) pos v) }

    | v= marked_identifier ColonColon t= expr
	{ let (pos,v) = v in make_F_Sigma oexp (v,hastype (id_to_expr pos v) t) }

    | v= marked_identifier ColonColonEqual e= expr ColonColon t= expr
	{ let (pos,v) = v in make_F_Sigma (with_pos_of e (J_Singleton(e,oexp))) (v,hastype (id_to_expr pos v) t) }

judgment_constant:

    | l= NAME
	{ let pos = Position($startpos, $endpos) in 
	  try lookup_judgment_constant pos l with Not_found -> $syntaxerror }

expr:

    | e= unmarked_expr
	{(Position($startpos, $endpos), e)}

    | e= parenthesized(expr) {e}

unmarked_expr:

    | LeftParen Kpair a= expr b= expr RightParen
    | LeftParen a= expr Comma b= expr RightParen
	{ PAIR(a, b) }

    | Lambda v= marked_identifier Comma body= expr
    | v= marked_identifier ArrowFromBar body= expr
	{ unmark (lambda1 (unmark v) body) }

    | empty_hole
	{$1}

    | head_and_args = short_head_and_reversed_expr_list
    | LeftParen head_and_args= expr_head_and_reversed_expr_list RightParen
	{ let (hd,args) = head_and_args in BASIC(hd,reverse_expr_list args) }

expr_head_and_reversed_expr_list:

    | head_and_args= expr_head_and_reversed_expr_list arg= expr
    | head_and_args= short_head_and_reversed_expr_list arg= expr
	{ app head_and_args arg }

    | head_and_args= expr_head_and_reversed_expr_list K_FST
    | head_and_args= short_head_and_reversed_expr_list K_FST
	{ car head_and_args }

    | head_and_args= expr_head_and_reversed_expr_list K_SND
    | head_and_args= short_head_and_reversed_expr_list K_SND
	{ cdr head_and_args }

short_head_and_reversed_expr_list:

    | tsterm_head
	{ $1, END }

    | identifier
	{ V (Var $1), END }

    | head_and_args= short_head_and_reversed_expr_list K_1
    | head_and_args= parenthesized(expr_head_and_reversed_expr_list) K_1
    	{ car head_and_args }

    | head_and_args= short_head_and_reversed_expr_list K_2
    | head_and_args= parenthesized(expr_head_and_reversed_expr_list) K_2
    	{ cdr head_and_args }

    | tac= closed_tactic_expr
	{ TACTIC tac, END }

closed_tactic_expr:

    | Dollar name= NAME
	{ name }

dotted_number: n= separated_nonempty_list(Period,NUMBER) {n} (* should disallow interior spaces eventually *)

command:

    | c= unmarked_command
	{ Position($startpos, $endpos), c }

    | error				(* instant error return for the sake of Proof General *)
	{ let pos = Position($startpos, $endpos) in
	  fprintf stderr "%a: syntax error\n%!" _pos pos;
	  bump_error_count pos;
	  pos, Toplevel.SyntaxError }

    | EOF { raise Eof }

unmarked_command:

    | Variable vars= marked_name+ Colon t= ts_expr EndOfProofStepMarker
	{ Toplevel.OVariable (vars,t) }

    | Variable vars= marked_name+ Type EndOfProofStepMarker
	{ Toplevel.TVariable vars }

    | Variable vars= marked_name+ Ulevel eqns= preceded(Semicolon,uEquation)* EndOfProofStepMarker
	{ Toplevel.UVariable (vars,eqns) }

    | Axiom num= dotted_number? name= NAME t= ts_judgment EndOfProofStepMarker
	{ Toplevel.Axiom (num,id name,t) }

    | Axiom LF num= dotted_number? name= identifier Colon t= judgment EndOfProofStepMarker
	{ Toplevel.Axiom (num,name,t) }

    | Check TS? o= ts_expr EndOfProofStepMarker
	{ Toplevel.CheckTS o }

    | Check LF e= expr EndOfProofStepMarker
	{ Toplevel.CheckLF e }

    | Check Judgment    t= ts_judgment EndOfProofStepMarker
    | Check Judgment LF t=    judgment EndOfProofStepMarker
	{ Toplevel.CheckType t }

    | Check Universes EndOfProofStepMarker
	{ Toplevel.CheckUniverses }

    | Alpha e1= ts_expr EqualEqual e2= ts_expr EndOfProofStepMarker
	{ Toplevel.Alpha (e1, e2) }

    | Theorem LF name= NAME Colon thm= judgment ColonEqual deriv= expr EndOfProofStepMarker
    | Theorem name= NAME thm= ts_judgment ColonColonEqual deriv= expr EndOfProofStepMarker
    | Theorem name= NAME thm= ts_judgment ColonEqual deriv= template_ts_expr EndOfProofStepMarker
	{
	  let pos = Position($startpos, $endpos) in
	  Toplevel.Theorem (pos, Some name, deriv, thm) }

    | Goal LF thm= judgment EndOfProofStepMarker
    | Goal thm= ts_judgment EndOfProofStepMarker
	{
	  let pos = Position($startpos, $endpos) in
	  Toplevel.Theorem (pos, None, (pos,default_tactic), thm) }

    | Theorem name= NAME thm= ts_judgment EndOfProofStepMarker
	{
	  let pos = Position($startpos, $endpos) in
	  Toplevel.Theorem (pos, Some name, (pos,default_tactic), thm) }

    | Include filename= STRING EndOfProofStepMarker
	{ 
	  let pos = Position($startpos, $endpos) in
	  Toplevel.Include (pos,filename) }

    | Clear EndOfProofStepMarker
	{ Toplevel.Clear }

    | Show n= NUMBER? EndOfProofStepMarker
	{ Toplevel.Show n }

    | Back n= NUMBER? EndOfProofStepMarker
	{ let n = match n with Some n -> n | None -> 1 in Toplevel.Back n }

    | BackTo n= NUMBER EndOfProofStepMarker
	{ Toplevel.BackTo n }

    | Mode TTS EndOfProofStepMarker
	{ Toplevel.Mode "TTS" }

    | Mode TS EndOfProofStepMarker
	{ Toplevel.Mode "TS" }

    | End EndOfProofStepMarker
	{ Toplevel.End }

uEquation:

    | u= ts_expr EqualEqual v= ts_expr
	{ (u,v) }

    | v= ts_expr GreaterEqual u= ts_expr
    | u= ts_expr LessEqual    v= ts_expr
	{ let pos = Position($startpos, $endpos) in (pos, make_U_max u v), v }

    | v= ts_expr Greater u= ts_expr
    | u= ts_expr Less    v= ts_expr
	{ let pos = Position($startpos, $endpos) in (pos, make_U_max (pos, make_U_next u) v), v }

parenthesized(X): x= delimited(LeftParen,X,RightParen) {x}

list_of_parenthesized(X): parenthesized(X)* {$1}

ts_exprEof: a= ts_expr EOF {a}

ts_judgment:

    | LeftParen t= unmarked_ts_judgment RightParen
    | t= unmarked_ts_judgment
	{ Position($startpos, $endpos), t }

unmarked_ts_judgment:

    | f= judgment_constant
	{ J_Basic(f,[]) }

    | LeftParen v= identifier Colon a= ts_judgment RightParen DoubleArrow b= ts_judgment
	{ make_F_Pi a (v,b) }

    | a= ts_judgment DoubleArrow b= ts_judgment
	{ unmark (a @-> b) }

    | LeftParen v= identifier Colon a= ts_judgment RightParen Times b= ts_judgment
	{ make_F_Sigma a (v,b) }

    | a= ts_judgment Times b= ts_judgment
	{ make_F_Sigma_simple a b }

    | a= ts_judgment TurnstileDouble b= ts_judgment
    	{ let v = good_var_name a (id "foo") in (* the "|-" operator is not fully implemented yet *)
	  let v = get_pos a, v in
	  unmark (pi1_implication (v,a) b) }

(* base judgments *)

    | Type
	{ let pos = Position($startpos, $endpos) in
	  let v = id "T" in
	  make_F_Sigma texp (v,(if !ts_mode then istype_v else witnessed_istype_v) pos v) }

    | Colon t= ts_expr
	{ let v = id "o" in
	  let pos = get_pos t in
	  make_F_Sigma oexp (v,with_pos pos (J_Basic(J_hastype, [id_to_expr pos v; t]))) }

    | Turnstile x= ts_expr Colon t= ts_expr
	{ unmark (this_object_of_type (get_pos x) x t) }

    | Turnstile a= ts_expr Type
        { let v = id "t" in
          let pos = get_pos a in
          let a = with_pos pos (J_Singleton(a,texp)) in
          let b = if !ts_mode then istype_v pos v else witnessed_istype_v pos v in
          make_F_Sigma a (v,b)
        }

    | j= ts_bracketed_judgment
	{ j }

(* introduction of parameters *)

    | j= ts_bracketed_judgment u= ts_judgment
	%prec Reduce_binder
        {
          let pos = Position($startpos, $endpos) in
          let jpos = Position($startpos(j), $endpos(j)) in
	  let w = apply_simple_binder pos (with_pos jpos j) u in
	  unmark w }

    | LeftBrace c= context vbj= separated_nonempty_list(Comma,pair(marked_identifier+,binder_judgment)) RightBrace u= ts_judgment
	%prec Reduce_binder
	{
	  let pos = Position($startpos, $endpos) in
	  let r = List.fold_right
	      (
	       fun (v,bj) u ->
		 let f = match bj with
		 | ULEV ->
		     if c <> [] then $syntaxerror;
		     fun v u -> with_pos_of v (make_F_Pi uexp (unmark v, u))
		 | IST ->
		     fun v u -> apply_binder pos c v texp u (if !ts_mode then istype_v else witnessed_istype_v)
		 | HAST t ->
		     fun v u -> apply_binder pos c v oexp u (if !ts_mode then hastype_v t else witnessed_hastype_v t)
		 | W_TEQ(t1,t2) ->
		     fun v u -> apply_binder pos c v wexp u (witnessed_type_equality_v t1 t2)
		 | W_OEQ(o1,o2,t) ->
		     fun v u -> apply_binder pos c v wexp u (witnessed_object_equality_v t o1 o2)
		 in List.fold_right f v u)
	      vbj u in
	  unmark r
	}

ts_bracketed_judgment:

    | LeftBracket a= ts_expr Type RightBracket
	{ unmark (if !ts_mode then istype a else witnessed_istype a) }

    | LeftBracket a= ts_expr EqualEqual b= ts_expr RightBracket
	{ unmark (type_equality a b) }

    | LeftBracket x= ts_expr Colon t= ts_expr RightBracket
	{ 
	  if !ts_mode
	  then unmark (hastype x t) 
	  else unmark (witnessed_hastype t x)
	}

    | LeftBracket x= ts_expr EqualEqual y= ts_expr Colon t= ts_expr RightBracket
	{ unmark (object_equality x y t) }

    | LeftBracket a= ts_expr Tilde b= ts_expr Ulevel RightBracket
	{ unmark (ulevel_equality a b) }

    | LeftBracket a= ts_expr Tilde b= ts_expr Type RightBracket
	{ unmark (type_uequality a b) }

    | LeftBracket a= ts_expr Tilde b= ts_expr Colon t= ts_expr RightBracket
	{ unmark (object_uequality a b t) }

    | LeftBracket p= ts_expr Colon a= ts_expr EqualEqual b= ts_expr RightBracket
	{ unmark (witnessed_type_equality a b p) }

    | LeftBracket p= ts_expr Colon x= ts_expr EqualEqual y= ts_expr Colon t= ts_expr RightBracket
	{ unmark (witnessed_object_equality t x y p) }

binder_judgment:

    | Ulevel { ULEV }

    | Type { IST }

    | Colon t= ts_expr { HAST t }

    | Colon x= ts_expr EqualEqual y= ts_expr { W_TEQ(x,y) }

    | Colon x= ts_expr EqualEqual y= ts_expr Colon t= ts_expr { W_OEQ(x,y,t) }

context:

    | c= terminated( separated_list( Comma,
			  separated_pair(
			       marked_identifier,
			       Colon, ts_expr)),
		     Turnstile)
	{c}

tsterm_head:

    | name= CONSTANT
	{ let pos = Position($startpos, $endpos) in try lookup_label pos name with Not_found -> $syntaxerror }

empty_hole: QuestionMark { default_tactic }

identifier:

    | NAME { id $1 }

marked_name:

    | NAME
	{ Position($startpos, $endpos), $1 }

marked_identifier: 

    | identifier
	{ Position($startpos, $endpos), $1 }

ts_expr:

    | e= parenthesized(ts_expr)
	{ e }

    | e= unmarked_ts_expr
	{ Position($startpos, $endpos), e }

ts_expr_list_member:

    | x= template_ts_expr
	{ Spine_arg x }

    | K_FST
	{ Spine_car }

    | K_SND
	{ Spine_cdr }

template_ts_expr:

    | ts_expr { $1 }

    | v= option(marked_identifier) Period body= template_ts_expr
	{ 
	  Position($startpos, $endpos),
	  let v = match v with Some v -> unmark v | None -> id "_" in
	  unmark (lambda1 v body)
	}

unmarked_ts_expr:

    | e= ts_expr K_1
    	{ unmark ( Substitute.apply_args e (FST END) ) }

    | e= ts_expr K_2
    	{ unmark ( Substitute.apply_args e (SND END) ) }

    | tac= closed_tactic_expr
	{ cite_tactic tac END }

    | f= ts_expr LeftBracket o= separated_list(Comma,ts_expr_list_member) RightBracket
	{ unmark (Substitute.apply_args f (expr_list_member_list_to_expr_list o)) }

    | identifier
	{ BASIC(V (Var $1),END) }

    | empty_hole {$1}

    | f= ts_expr o= ts_expr
	%prec Reduce_application
	{ let pos = Position($startpos, $endpos) in BASIC(O O_ev, f ** o ** (pos, default_tactic) ** (pos, default_tactic) ** END) }

    | LeftParen x= identifier Colon t= ts_expr RightParen ArrowFromBar o= ts_expr
    | Lambda x= identifier Colon t= ts_expr Comma o= ts_expr
	%prec Reduce_binder
	{ make_O_lambda  t (x,o) }

    | Star o= ts_expr
	{ make_T_El o }

    | Pi x= identifier Colon t1= ts_expr Comma t2= ts_expr
	%prec Reduce_binder
	{ make_T_Pi t1 (x,t2) }

    | LeftParen x= identifier Colon t= ts_expr RightParen Arrow u= ts_expr
	{ make_T_Pi t (x,u) }

    | x= ts_expr Equal y= ts_expr
	{ make_T_Id (with_pos_of x (cite_tactic "tn12" END)) x y }

    | t= ts_expr Arrow u= ts_expr
	{ make_T_Pi t (id "_",u) }

    | Sigma x= identifier Colon t1= ts_expr Comma t2= ts_expr
	%prec Reduce_binder
	{ make_T_Sigma t1 (x,t2) }

    | Kumax LeftParen u= ts_expr Comma v= ts_expr RightParen
	{ BASIC(U U_max, u**v**END)  }

    | label= tsterm_head
	{ BASIC(label, END ) }

    | LeftParen a= template_ts_expr Comma b= template_ts_expr RightParen
	{ PAIR(a,b) }

(*
  Local Variables:
  compile-command: "make -C .. src/parser.cmo "
  End:
 *)

