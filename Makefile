OCAMLOPT=ocamlopt
OCAMLC=ocamlc

INCL=$(shell $(OCAMLC) -where)/site-lib/camlimages

#OCAMLNLDFLAGS = -ccopt -static
OCAMLFLAGS = -unsafe

VERSION=0.1.9

SRCML=tga2cry.ml version.ml converter.ml 
PROJECT=converter

LIBS=unix graphics camlimages

BYTELIBS=$(LIBS:=.cma)
NATIVELIBS=$(LIBS:=.cmxa)

CMO=$(SRCML:.ml=.cmo)
CMX=$(SRCML:.ml=.cmx)

all: $(PROJECT).native $(PROJECT).byte

.PHONY: all clean

$(PROJECT).native: $(CMX)
	$(OCAMLOPT) -I $(INCL) -o $@ $(NATIVELIBS) $^

$(PROJECT).byte: $(CMO)
	$(OCAMLC) -I $(INCL) -o $@ $(BYTELIBS) $^

version.ml: Makefile
	@echo "let date_of_compile=\""`date`"\";;" > $@
	@echo "let version=\""$(VERSION)"\";;" >> $@
	@echo "let build_info=\""`uname -msrn`"\";;" >> $@

%.cmo: %.ml
	$(OCAMLC) -I $(INCL) -c $(OCAMLFLAGS) -o $@ $<

%.cmx: %.ml
	$(OCAMLOPT) -I $(INCL) -c $(OCAMLFLAGS) -o $@ $<

clean:
	rm -f $(CMO) $(CMX) version.ml
