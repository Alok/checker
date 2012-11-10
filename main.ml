let _ = (
  let lexbuf = Lexing.from_channel stdin in
  while true do
    try
      let _ = Expressions.expr Tokens.main lexbuf in
      Printf.printf "expr found\n"; flush stdout;
      ()
    with 
      Tokens.Eof -> exit 0
    | Parsing.Parse_error -> 
	Tokens.curry3 (Printf.fprintf stderr "%s:%d:%d: syntax error\n") (Tokens.position lexbuf);
	flush stderr;
	Lexing.flush_input lexbuf
  done
  )
