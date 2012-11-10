{
 open Printf
 open Expressions
 exception Eof
}
let white = [ '\n' ' ' '\t' '\r' ]
let tfirst = [ 'A'-'Z' ]
let ofirst = [ 'a'-'z' ]
let ufirst = 'U' 'U'
let after = [ 'A'-'Z' 'a'-'z' '0'-'9' ]
rule main = parse
  | '('  { Wlparen }
  | ')'  { Wrparen }
  | '['  { Wlbracket }
  | ']'  { Wrbracket }
  | ';'  { Wsemi }
  | ufirst after* as id { UVar id }
  | tfirst after* as id { TVar id }
  | ofirst after* as id { OVar id }
  | white { main lexbuf }
  | _ as c { printf "invalid character: '%c'\n" c; main lexbuf }
  | eof { raise Eof }
