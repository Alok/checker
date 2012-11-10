%: %.ml; ocamlc -g -annot $<
%.cmo: %.ml; ocamlc -g -c -annot $<
%.cmi: %.mli; ocamlc -g -c -annot $<
%.ml: %.mll; ocamllex $< -o $@
%.ml: %.mly; ocamlyacc $< && ocamlc -g $*.mli

all : checker doc TAGS
run : checker
	./checker
doc: doc.pdf
doc.pdf: typesystem.ml
	ocamldoc -charset utf8 -notoc -o doc.tex-out -latex $^
	pdflatex doc.tex-out
	pdflatex doc.tex-out
checker: typesystem.cmo expressions.cmo tokens.cmo main.cmo
	ocamlc -g -o $@ $^
top: interp.cmo typesystem.cmo expressions.cmo tokens.cmo
	ocaml $^
tokens.ml: expressions.ml
tokens.cmo: expressions.cmo
expressions.cmo: expressions.cmi
main.cmo: tokens.cmi expressions.cmi
TAGS: typesystem.ml
	etags.ocaml $^ >$@
clean:
	rm -f *.annot *.cmi *.cmo a.out *-tmp.ml *.aux *.dvi *.log *.out *.pdf *.sty *.toc *.tex-out checker
	rm -f expressions.mli expressions.ml tokens.ml TAGS
