#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output=${1:-"$repo_dir/converter.native"}
if [[ $output != /* ]]; then
    output="$PWD/$output"
fi

for tool in opam cc make pkg-config; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Commande requise : %s\n' "$tool" >&2
        exit 1
    fi
done

if ! pkg-config --exists libjpeg libpng libtiff-4 xpm ||
   ! printf '#include <gif_lib.h>\nint main(void) { return GifErrorString(0) != 0; }\n' |
       cc -x c - -lgif -o /dev/null; then
    printf 'Installez les fichiers de développement de GIF, JPEG, PNG, TIFF et Xpm. Voir README.\n' >&2
    exit 1
fi

opam_root=${JCONVERTER_OPAM_ROOT:-"${XDG_CACHE_HOME:-$HOME/.cache}/jconverter/opam"}
switch=jconverter-5.1.1
if [[ ! -f $opam_root/config ]]; then
    opam init --root="$opam_root" --bare --no-setup --yes
fi
if [[ ! -f $opam_root/$switch/.opam-switch/switch-state ]]; then
    opam switch create "$switch" ocaml-base-compiler.5.1.1 --root="$opam_root" --yes
fi
opam install --root="$opam_root" --switch="$switch" --yes --deps-only camlimages.5.0.5

build_dir=$(mktemp -d)
trap 'rm -rf -- "$build_dir"' EXIT
camlimages_dir="$build_dir/camlimages"
opam source --root="$opam_root" --switch="$switch" --dir="$camlimages_dir" camlimages.5.0.5

# These stubs override Dune's default C flags and need PIC for shared linking.
for format in jpeg png tiff xpm; do
    sed -i "s|(:include ../config/${format}_c_flags.sexp)|-fPIC &|" "$camlimages_dir/$format/dune"
done
(
    cd "$camlimages_dir"
    opam exec --root="$opam_root" --switch="$switch" -- dune build -p camlimages @install
)

cp "$repo_dir"/{Makefile,converter.ml,tga2cry.ml} "$build_dir/"
cd "$build_dir"
make version.ml
opam exec --root="$opam_root" --switch="$switch" -- \
    env OCAMLPATH="$camlimages_dir/_build/install/default/lib" \
    ocamlfind ocamlopt -linkpkg -linkall \
    -package camlimages.core,camlimages.gif,camlimages.jpeg,camlimages.png,camlimages.tiff,camlimages.xpm \
    -o converter.native tga2cry.ml version.ml converter.ml
install -m 755 converter.native "$output"
printf 'Exécutable : %s\n' "$output"
