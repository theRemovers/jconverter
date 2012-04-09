#!/bin/sh

PACKAGE=camlimages-3.0.2

tar xfvz "$PACKAGE.tar.gz"

for i in *.patch
do
    cd "$PACKAGE"
    patch -p0 < "../$i"
    cd ..
done

cd "$PACKAGE"
./configure --without-lablgtk --without-lablgtk2

make
