#!/bin/sh

PACKAGE=camlimages-3.0.2

tar xfvz "$PACKAGE.tar.gz"

cd "$PACKAGE"

patch -p0 <<EOF
--- src/pngread.c	2009-10-26 13:42:03.000000000 +0100
+++ src/pngread.c	2012-04-08 19:40:11.908427706 +0200
@@ -69,7 +69,7 @@
   }
 
   /* error handling */
-  if (setjmp(png_ptr->jmpbuf)) {
+  if (setjmp(png_jmpbuf(png_ptr))) {
     /* Free all of the memory associated with the png_ptr and info_ptr */
     png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
     fclose(fp);
@@ -134,7 +134,7 @@
     png_set_rows(png_ptr, info_ptr, row_pointers);
 
     /* Later, we can return something */
-    if (setjmp(png_ptr->jmpbuf)) {
+    if (setjmp(png_jmpbuf(png_ptr))) {
       /* Free all of the memory associated with the png_ptr and info_ptr */
       png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
       fclose(fp);
@@ -243,7 +243,7 @@
   }
 
   /* error handling */
-  if (setjmp(png_ptr->jmpbuf)) {
+  if (setjmp(png_jmpbuf(png_ptr))) {
     /* Free all of the memory associated with the png_ptr and info_ptr */
     png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
     fclose(fp);
@@ -302,7 +302,7 @@
     png_set_rows(png_ptr, info_ptr, row_pointers);
 
     /* Later, we can return something */
-    if (setjmp(png_ptr->jmpbuf)) {
+    if (setjmp(png_jmpbuf(png_ptr))) {
       /* Free all of the memory associated with the png_ptr and info_ptr */
       png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
       fclose(fp);
EOF

patch -p0 <<EOF
--- src/pngwrite.c	2009-10-26 13:42:03.000000000 +0100
+++ src/pngwrite.c	2012-04-08 19:40:15.611741213 +0200
@@ -62,7 +62,7 @@
   }
 
   /* error handling */
-  if (setjmp(png_ptr->jmpbuf)) {
+  if (setjmp(png_jmpbuf(png_ptr))) {
     /* Free all of the memory associated with the png_ptr and info_ptr */
     png_destroy_write_struct(&png_ptr, &info_ptr);
     fclose(fp);
@@ -171,7 +171,7 @@
   }
 
   /* error handling */
-  if (setjmp(png_ptr->jmpbuf)) {
+  if (setjmp(png_jmpbuf(png_ptr))) {
     /* Free all of the memory associated with the png_ptr and info_ptr */
     png_destroy_write_struct(&png_ptr, &info_ptr);
     fclose(fp);
EOF

./configure --without-lablgtk --without-lablgtk2

make

echo "Please type now"
echo "cd $PACKAGE"
echo "sudo make install"
