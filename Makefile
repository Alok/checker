BFLAGS = -cflags -g,-annot -lflags -g -yaccflag -v
BFLAGS += -use-menhir

# add -yaccflag --trace to ocamlbuild command line to get the menhir parser to display a trace
# BFLAGS += -yaccflag --trace

# BFLAGS += -verbose 0
SRCFILES =					\
	typesystem.ml				\
	alpha.ml				\
	universe.ml				\
	substitute.ml				\
	check.ml				\
	equality.ml				\
	fillin.ml				\
	tau.ml					\
	derivation.ml				\
	printer.ml				\
	grammar.mly				\
	tokens.mll				\
	toplevel.ml				\
	checker.ml

BASENAMES = $(patsubst %.mly, %, $(patsubst %.mll, %, $(patsubst %.ml, %, $(SRCFILES))))

# add ,p to get the ocamlyacc parser to display a trace
RUN = -b
# RUN = -b,p

%.cmo: %.ml; ocamlbuild $(BFLAGS) $*.cmo

all: TAGS run doc
checker.byte checker.native: $(SRCFILES); ocamlbuild $(BFLAGS) $@
doc: checker.odocl
	ocamlbuild $(BFLAGS) checker.docdir/index.html
checker.odocl: Makefile
	for i in $(BASENAMES) ; do echo $$i ; done >$@
clean::; ocamlbuild -clean
TAGS: $(SRCFILES) test.ts scripts/ts.etags
	( scripts/etags.ocaml $(SRCFILES) && etags --regex=@scripts/ts.etags test.ts -o - ) >$@
clean::; rm -f TAGS checker.odocl
wc:; wc -l $(SRCFILES) Makefile test.ts
run: checker.byte; OCAMLRUNPARAM=$(RUN) ./$< test.ts
run_nofile: checker.byte; OCAMLRUNPARAM=$(RUN) ./$<
run.native: checker.native; OCAMLRUNPARAM=$(RUN) ./$< <test.ts
