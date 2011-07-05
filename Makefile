OCAMLMAKEFILE = OCamlMakefile

OCAMLNLDFLAGS = -ccopt -static
OCAMLFLAGS = -unsafe

OCAMLC = ocamlc

VERSION = version.ml

SOURCES = tga2cry.ml $(VERSION) converter.ml 
RESULT  = converter
INCDIRS = $(shell $(OCAMLC) -where)/camlimages
LIBS = ci_core ci_bmp ci_gif ci_jpeg ci_png ci_ppm ci_tiff

TRASH = $(VERSION)

all: $(VERSION) nc

include $(OCAMLMAKEFILE)

$(VERSION): Makefile
	@echo "let date_of_compile=\""`date`"\";;" > $@
	@echo "let version=\""$(VERSION)"\";;" >> $@
	@echo "let build_info=\""`uname -msrn`"\";;" >> $@
