OCAMLMAKEFILE = OCamlMakefile

OCAMLNLDFLAGS = -ccopt -static
OCAMLFLAGS = -unsafe

OCAMLC = ocamlc

SOURCES = tga2cry.ml version.ml converter.ml 
RESULT  = converter
INCDIRS = $(shell $(OCAMLC) -where)/camlimages
LIBS = ci_core ci_bmp ci_gif ci_jpeg ci_png ci_ppm ci_tiff

TRASH = version.ml

all: version.ml nc

include $(OCAMLMAKEFILE)

version.ml: Makefile
	@echo "let date_of_compile=\""`date`"\";;" > version.ml
	@echo "let version=\""$(VERSION)"\";;" >> version.ml
	@echo "let build_info=\""`uname -msrn`"\";;" >> version.ml
