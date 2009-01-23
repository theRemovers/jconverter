OCAMLMAKEFILE = OCamlMakefile

OCAMLNLDFLAGS = -ccopt -static
OCAMLFLAGS = -unsafe

OCAMLC = ocamlc

SOURCES = tga2cry.ml compile_info.ml converter.ml 
RESULT  = converter
INCDIRS = $(shell $(OCAMLC) -where)/site-lib/camlimages
LIBS = ci_core ci_bmp ci_gif ci_jpeg ci_png ci_ppm ci_tiff

TRASH = compile_info.ml

all: compile_info.ml nc

include $(OCAMLMAKEFILE)

compile_info.ml: Makefile
	@echo "let date_of_compile=\""`date`"\";;" > compile_info.ml
	@echo "let version=\""$(VERSION)"\";;" >> compile_info.ml
	@echo "let build_info=\""`uname -msrn`"\";;" >> compile_info.ml
