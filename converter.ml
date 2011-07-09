(*
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
#  USA.
*)

open Images
open OImages
open Info

let floyd_steinberg = 16, [| [| 0; 0; 0 |]; 
			     [| 0; 0; 7 |]; 
			     [| 3; 5; 1 |]; |]

let jarvis_judice_ninke =  48, [| [|0; 0; 0; 0; 0|];
			          [|0; 0; 0; 0; 0|];
			          [|0; 0; 0; 7; 5|];
			          [|3; 5; 7; 5; 3|];
			          [|1; 3; 5; 3; 1|]; |]

let filter = floyd_steinberg
(* let filter = jarvis_judice_ninke *)

type output = Rgb16 | Cry16

let output_format = ref Rgb16

let dithering = ref false

let clut_mode = ref false

let ascii_output = ref true

let target_dir = ref "./"

let overwrite = ref false

let opt_clut = ref false

let bpp_clut = ref 8

let mode15bit = ref false

let rgb24mode = ref false

let gray = ref false

let glass = ref false

let texture = ref false

let keep_positive = ref true
let keep_negative = ref true

let rotate = ref false
let rotate_angle = ref 0

let cut = ref false
let cut_x = ref 0
let cut_y = ref 0
let cut_w = ref 0
let cut_h = ref 0

let sample = ref false
let sample_w = ref 0
let sample_h = ref 0

let aworld = ref false

let use_tga2cry = ref true

exception CannotSplit

let split_string s c p =
  let n = String.length s in
  let i = ref 0 in
    while (if (!i < n) then s.[!i] <> c else false) do
      if not (p (s.[!i])) then raise CannotSplit;
      incr i
    done;
    if !i < n then 
      let s1 = String.sub s 0 !i 
      and s2 = String.sub s (!i+1) (n- !i -1) in
	s1,s2
    else raise CannotSplit

let isDigit = function '0'..'9' -> true | _ -> false

let analyse_cut_string s =
  cut := false;
  let s = s^"^" in
  try
    let x,s = split_string s ',' isDigit in
    let y,s = split_string s ':' isDigit in
    let w,s = split_string s 'x' isDigit in
    let h,s = split_string s '^' isDigit in
      if String.length s > 0 then raise CannotSplit;
      cut := true;
      cut_x := int_of_string x;
      cut_y := int_of_string y;
      cut_w := int_of_string w;
      cut_h := int_of_string h
  with CannotSplit -> ()

let analyse_sample_string s =
  sample := false;
  let s = s^"^" in
  try
    let w,s = split_string s 'x' isDigit in
    let h,s = split_string s '^' isDigit in
      if String.length s > 0 then raise CannotSplit;
      sample := true;
      sample_w := int_of_string w;
      sample_h := int_of_string h
  with CannotSplit -> ()

let rebuild_cut_string () =
  if !cut then (string_of_int !cut_x)^","^(string_of_int !cut_y)^":"^(string_of_int !cut_w)^"x"^(string_of_int !cut_h)
  else ""

let rgb24_of_rgb24 c = 
  let v1 = ((c.r land 0xff) lsl 8) lor (c.g land 0xff)
  and v2 = c.b land 0xff in
    (v1,v2)

let rgb16_of_rgb24 c = 
  let r = (c.r lsr 3) land 0x1f
  and g = (c.g lsr 2) land 0x3f
  and b = (c.b lsr 3) land 0x1f
  in
    (r lsl 11) lor (b lsl 6) lor g

let pi = 4. *. atan(1.)

let rad_of_deg x = (x *. 2. *. pi) /. 360.

let cosd x = cos (rad_of_deg (float_of_int x))
let sind x = sin (rad_of_deg (float_of_int x))
let tand x = tan (rad_of_deg (float_of_int x))

let round x = int_of_float (x +. 0.5) 

let check_pos_neg x =
  if !keep_positive && !keep_negative then x
  else
    if !keep_positive then max x 0
    else if !keep_negative then min x 0
    else 0

let get_cry_value (c,r,y) =
  if !gray then 
    if !glass then (check_pos_neg (y - 0x80)) land 0xff
    else y
  else if !glass then 
    (((check_pos_neg (c - 8)) land 0xf) lsl 12) lor (((check_pos_neg (r - 8)) land 0xf) lsl 8) lor ((check_pos_neg (y - 0x80)) land 0xff)
  else if !texture then ((c lsl 12) lor (r lsl 8) lor y) lxor 0x0080
  else (c lsl 12) lor (r lsl 8) lor y 

let cry16_of_rgb24_compute c =
  let sat4 n = min (max n 0) 15 in
    if c.r = 0 && c.g = 0 && c.b = 0 then 0 
    else
      let y = max (max c.r c.g) c.b in
      let f x = if y = 0 then 0. else (float_of_int (x * 255)) /. (float_of_int y) in
      let r_d,g_d,b_d = (f c.r),(f c.g),(f c.b) in
      let x = (cosd 30) *. r_d -. (cosd 30) *. b_d 
      and w = -. (sind 30) *. r_d +. g_d -. (sind 30) *. b_d 
    in
      let x',y' =
	if (w >= x *. (tand (-30))) && (w <= x *. (tand 30)) then 
	  (x /. (34. *. (cosd 30))),(w /. 17.)
	else 
	  (x /. (34. *. (cosd 30))),(w /. 34.)
      in
      let c = x' +. 7.5 and r = y' +. 7.5 in
      let (c,r,y) = (sat4 (round c)),(sat4 (round r)),y in
      let c = c land 0xf 
      and r = r land 0xf
      in get_cry_value (c,r,y)

let cry16_of_rgb24_table c =
  let y = max c.r (max c.g c.b) in
  let f v = ((v * 255) / y) lsr 3 in
  let (xx,yy,zz) = 
    if y = 0 then (0,0,0)
    else (f c.r,f c.g,f c.b)
  in 
  let cr = Tga2cry.get_value xx yy zz in
  let c = (cr lsr 4) land 0xf
  and r = cr land 0xf
  in get_cry_value (c,r,y)

let cry16_of_rgb24 c = 
  if !use_tga2cry then cry16_of_rgb24_table c
  else cry16_of_rgb24_compute c

let rgb24_of_cry16 =
  let red = [|0; 0; 0; 0; 0; 0; 0; 0; 
	      0; 0; 0; 0; 0; 0; 0; 0;
	      34; 34; 34; 34; 34; 34; 34; 34;
	      34; 34; 34; 34; 34; 34; 19; 0;
	      68; 68; 68; 68; 68; 68; 68; 68;
	      68; 68; 68; 68; 64; 43; 21; 0;
	      102; 102; 102; 102; 102; 102; 102; 102;
	      102; 102; 102; 95; 71; 47; 23; 0;
	      135; 135; 135; 135; 135; 135; 135; 135;
	      135; 135; 130; 104; 78; 52; 26; 0;
	      169; 169; 169; 169; 169; 169; 169; 169;
	      169; 170; 141; 113; 85; 56; 28; 0;
	      203; 203; 203; 203; 203; 203; 203; 203;
	      203; 183; 153; 122; 91; 61; 30; 0;
	      237; 237; 237; 237; 237; 237; 237; 237;
	      230; 197; 164; 131; 98; 65; 32; 0;
	      255; 255; 255; 255; 255; 255; 255; 255;
	      247; 214; 181; 148; 115; 82; 49; 17;
	      255; 255; 255; 255; 255; 255; 255; 255;
	      255; 235; 204; 173; 143; 112; 81; 51;
	      255; 255; 255; 255; 255; 255; 255; 255;
	      255; 255; 227; 198; 170; 141; 113; 85;
	      255; 255; 255; 255; 255; 255; 255; 255;
	      255; 255; 249; 223; 197; 171; 145; 119;
	      255; 255; 255; 255; 255; 255; 255; 255;
	      255; 255; 255; 248; 224; 200; 177; 153;
	      255; 255; 255; 255; 255; 255; 255; 255; 
	      255; 255; 255; 255; 252; 230; 208; 187;
	      255; 255; 255; 255; 255; 255; 255; 255; 
	      255; 255; 255; 255; 255; 255; 240; 221;
	      255; 255; 255; 255; 255; 255; 255; 255; 
	      255; 255; 255; 255; 255; 255; 255; 255|]
  and green = [|0; 17; 34; 51; 68; 85; 102; 119;
		136; 153; 170; 187; 204; 221; 238; 255;
		0; 19; 38; 57; 77; 96; 115; 134;
		154; 173; 192; 211; 231; 250; 255; 255;
		0; 21; 43; 64; 86; 107; 129; 150;
		172; 193; 215; 236; 255; 255; 255; 255;
		0; 23; 47; 71; 95; 119; 142; 166;
		190; 214; 238; 255; 255; 255; 255; 255;
		0; 26; 52; 78; 104; 130; 156; 182;
		208; 234; 255; 255; 255; 255; 255; 255;
		0; 28; 56; 85; 113; 141; 170; 198;
		226; 255; 255; 255; 255; 255; 255; 255;
		0; 30; 61; 91; 122; 153; 183; 214;
		244; 255; 255; 255; 255; 255; 255; 255;
		0; 32; 65; 98; 131; 164; 197; 230;
		255; 255; 255; 255; 255; 255; 255; 255;
		0; 32; 65; 98; 131; 164; 197; 230;
		255; 255; 255; 255; 255; 255; 255; 255;
		0; 30; 61; 91; 122; 153; 183; 214;
		244; 255; 255; 255; 255; 255; 255; 255;
		0; 28; 56; 85; 113; 141; 170; 198;
		226; 255; 255; 255; 255; 255; 255; 255;
		0; 26; 52; 78; 104; 130; 156; 182;
		208; 234; 255; 255; 255; 255; 255; 255;
		0; 23; 47; 71; 95; 119; 142; 166;
		190; 214; 238; 255; 255; 255; 255; 255;
		0; 21; 43; 64; 86; 107; 129; 150; 
		172; 193; 215; 236; 255; 255; 255; 255;
		0; 19; 38; 57; 77; 96; 115; 134;
		154; 173; 192; 211; 231; 250; 255; 255;
		0; 17; 34; 51; 68; 85; 102; 119; 
		136; 153; 170; 187; 204; 221; 238; 255|]
  and blue = [|255; 255; 255; 255; 255; 255; 255; 255;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       255; 255; 255; 255; 255; 255; 240; 221;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       255; 255; 255; 255; 252; 230; 208; 187;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       255; 255; 255; 248; 224; 200; 177; 153;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       255; 255; 249; 223; 197; 171; 145; 119;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       255; 255; 227; 198; 170; 141; 113; 85;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       255; 235; 204; 173; 143; 112; 81; 51;
	       255; 255; 255; 255; 255; 255; 255; 255;
	       247; 214; 181; 148; 115; 82; 49; 17;
	       237; 237; 237; 237; 237; 237; 237; 237;
	       230; 197; 164; 131; 98; 65; 32; 0;
	       203; 203; 203; 203; 203; 203; 203; 203;
	       203; 183; 153; 122; 91; 61; 30; 0;
	       169; 169; 169; 169; 169; 169; 169; 169;
	       169; 170; 141; 113; 85; 56; 28; 0;
	       135; 135; 135; 135; 135; 135; 135; 135;
	       135; 135; 130; 104; 78; 52; 26; 0;
	       102; 102; 102; 102; 102; 102; 102; 102;
	       102; 102; 102; 95; 71; 47; 23; 0;
	       68; 68; 68; 68; 68; 68; 68; 68; 
	       68; 68; 68; 68; 64; 43; 21; 0;
	       34; 34; 34; 34; 34; 34; 34; 34;
	       34; 34; 34; 34; 34; 34; 19; 0;
	       0; 0; 0; 0; 0; 0; 0; 0;
	       0; 0; 0; 0; 0; 0; 0; 0|]
  in
    function c ->
      let i = c lsr 8
      and y = c land 0xff in
      let r = (red.(i) * y) lsr 8
      and g = (green.(i) * y) lsr 8
      and b = (blue.(i) * y) lsr 8
      in { r = r; g = g; b = b }

let rgb24_of_cry15 n = rgb24_of_cry16 (n land 0xfffe)

let rgb24_of_rgb16 n = 
  let r = ((n lsr 11) land 0x1f) lsl 3
  and g = (n land 0x3f) lsl 2
  and b = ((n lsr 6) land 0x1f) lsl 3
  in { r = r; g = g; b = b }

let rgb24_of_rgb15 n = rgb24_of_rgb16 n

let rgb15_of_rgb16 n = if n = 0 then n else n lor 0x1

let cry15_of_cry16 n = n land 0xfffe

let rgb15_of_rgb24 c = rgb15_of_rgb16 (rgb16_of_rgb24 c)

let cry15_of_rgb24 c = cry15_of_cry16 (cry16_of_rgb24 c)

let string_of_char c = String.make 1 c 

let hexstring_of_int ?(dollar = true) nb n =
  let s = ref "" and n = ref n in
    for i = 0 to nb-1 do
      let d = !n land 0xf in
	n := !n lsr 4;
	if (0 <= d) && (d <= 9) then s := (string_of_char (Char.chr (d+(Char.code '0'))))^(!s)
	else s := (string_of_char (Char.chr (d-10+(Char.code 'A'))))^(!s)
    done;
    (if dollar then "$" else "")^(!s)

let cry_attribute () =
  if !gray then 
    if !glass then " (gray & glass)"
    else " (gray)"
  else
    if !glass then " (glass)"
    else ""

let description_of_format () = 
  if !rgb24mode then
    "RGB 24 bits"
  else
    if !clut_mode then
      "Pixel map ("^(string_of_int !bpp_clut)^" bits per pixel)"
    else
      match !output_format with
	| Rgb16 -> "Jaguar RGB "^(if !mode15bit then "15" else "16")
	| Cry16 -> "Jaguar CRY "^(if !mode15bit then "15" else "16")^(cry_attribute())

let load_image src =
  prerr_string "Loading file ";prerr_string src;prerr_newline();
  let img = OImages.load src [] in
    img

let name_label basename =
  if !clut_mode then basename^"_map"
  else basename^"_gfx"

let name_dst basename =
  let basename = basename^(rebuild_cut_string ()) in
  if !ascii_output then basename^".s" 
  else 
    if !rgb24mode then basename^".rgb24"
    else
      if !clut_mode then basename^".map"
      else
	match !output_format with
	  | Rgb16 -> basename^".rgb"
	  | Cry16 -> basename^".cry"

let name_label_clut basename = basename^"_pal"

let name_clut basename =
  if !ascii_output then
    match !output_format with
      | Rgb16 -> basename^"_rgb_pal.s"
      | Cry16 -> basename^"_cry_pal.s"
  else
    match !output_format with
      | Rgb16 -> basename^"_rgb.pal"
      | Cry16 -> basename^"_cry.pal"

let adjust_width w =
  let w' = 
    if !rgb24mode then
      (((w*4)+7)/8)*2
    else
      if !clut_mode then 
	let q1 = w/(8 / !bpp_clut) in
	let q1 = 
	  if w mod (8 / !bpp_clut) = 0 then q1
	  else q1+1
	in
	let q = q1 / 8 in
	let q = 
	  if q1 mod 8 = 0 then q
	  else q+1
	in
	  q * 8 * (8 / !bpp_clut)
      else  (((w*2)+7)/8)*4 
  in
    if w' <> w then
      begin
	prerr_string "extending width from ";
	prerr_int w;
	prerr_string " to ";
	prerr_int w';
	prerr_newline()
      end;
    w'

let phrase_width w =
  if !rgb24mode then
    (assert (w mod 2 = 0);w/2)
  else
    if !clut_mode then 
      let q1 = w/(8 / !bpp_clut) in
      let q1 = 
	if w mod (8 / !bpp_clut) = 0 then q1
	else q1+1
      in
	(assert(q1 mod 8 = 0);q1/8)
    else (assert(w mod 4 = 0);w/4)

let tool_info () =
  "; Converted with 'Jaguar image converter' (version "^(Version.version)^") by Seb/The Removers\n"

let output_header stream src labelname w h = 
  if !ascii_output then
    begin
      output_string stream (tool_info ());
      output_string stream "\t.phrase\n";
      output_string stream (labelname^":\n");
      output_string stream ("; "^(Filename.basename src)^"\n");
      output_string stream ("; "^(string_of_int w)^" x "^(string_of_int h)^"\n");
      output_string stream ("; "^(description_of_format ())^"\n");
      output_string stream ("; "^(string_of_int (phrase_width w))^" phrases per line\n");
    end

let description_of_pal () =
  match !output_format with
    | Rgb16 -> "CLUT RGB "^(if !mode15bit then "15" else "16")
    | Cry16 -> "CLUT CRY "^(if !mode15bit then "15" else "16")

let output_clut_header stream src labelname nb = 
  if !ascii_output then
    begin
      output_string stream (tool_info ());
      output_string stream "\t.phrase\n";
      output_string stream (labelname^":\n");
      output_string stream ("; "^(Filename.basename src)^"\n");
      output_string stream ("; "^(string_of_int nb)^" colors\n");
      output_string stream ("; "^(description_of_pal ())^"\n")
    end

let safe_open_out s =
  if !overwrite then
    Some(open_out s)
  else
    try
      let stream = open_in s in
	close_in stream;
	None
    with _ -> Some(open_out s)

let counter_by_line = 16

let reset_ascii,finish_ascii,output_ascii_long,output_ascii_word,output_ascii_byte =
  let counter = ref 0 in
  let reset_ascii () = counter := 0
  and finish_ascii stream = 
    if !ascii_output then output_string stream "\n"
  and output_ascii header stream value = 
    if !counter = 0 then output_string stream ("\t"^header^"\t")
    else output_string stream ", ";
    output_string stream value;
    incr counter;
    if !counter >= counter_by_line then
      begin
	output_string stream "\n"; 
	counter := 0
      end
  in
  let output_ascii_long stream (v1,v2) = output_ascii "dc.l" stream ((hexstring_of_int 4 v1)^(hexstring_of_int ~dollar:false 4 v2))
  and output_ascii_word stream v = output_ascii "dc.w" stream (hexstring_of_int 4 v)
  and output_ascii_byte stream v = output_ascii "dc.b" stream (hexstring_of_int 2 v)
  in reset_ascii,finish_ascii,output_ascii_long,output_ascii_word,output_ascii_byte

let write_out dstname f =
  let ostream = try safe_open_out dstname with _ -> None in
    match ostream with
      | None -> prerr_string ("error while creating "^dstname);prerr_newline()
      | Some(stream)  -> 
	  begin
	    reset_ascii ();
	    f stream;
	    finish_ascii stream;
	    close_out stream
	  end

let output_word stream v =
  let h = (v lsr 8) land 0xff
  and l = v land 0xff in
    output_byte stream h;
    output_byte stream l

let output_long stream (v1,v2) = 
  output_word stream v1;
  output_word stream v2

let out_long stream v =
  if !ascii_output then output_ascii_long stream v
  else output_long stream v

let out_word stream v =
  if !ascii_output then
    output_ascii_word stream v
  else
    output_word stream v

let out_byte stream v =
  if !ascii_output then
    output_ascii_byte stream v
  else
    output_byte stream (v land 0xff)

let get_coords img =
  let w,h = 
    if !sample then !sample_w, !sample_h
    else img#width, img#height
  in
    if !cut then
      w, h, !cut_x,!cut_y,!cut_w,!cut_h
    else
      w, h, 0, 0, w, h

let do_file src =
  let img = load_image src in
  let name = Filename.chop_extension src in
  let basename = Filename.basename name in
  let labelname = name_label basename in
  let dst = name_dst basename in
  let conv,invconv = 
    match !output_format with 
      | Rgb16 -> 
	  if !mode15bit then rgb15_of_rgb24,rgb24_of_rgb15
	  else rgb16_of_rgb24,rgb24_of_rgb16
      | Cry16 -> 
	  if !mode15bit then cry15_of_rgb24,rgb24_of_cry15
	  else cry16_of_rgb24,rgb24_of_cry16
  in
  let read img w h x y black =
    let real_read =
      let fx, fy = 
	if !sample then
	  img#width / !sample_w, img#height / !sample_h
	else 1, 1
      in
	fun x y ->
	  if (0 <= x) && (x < w) && (0 <= y) && (y < h) then img#unsafe_get (x * fx) (y * fy) 
	  else black
    in
      if !rotate && (not !cut) then
	let xo = (float_of_int w) /. 2. and yo = (float_of_int h) /. 2. in
	let xi = (float_of_int x) -. xo
	and yi = (float_of_int y) -. yo in
	let ca = cosd (- !rotate_angle) and sa = sind (- !rotate_angle) in
	let xj = xo +. xi *. ca -. yi *. sa
	and yj = yo +. xi *. sa +. yi *. ca 
	in 
	let x' = round xj
	and y' = round yj in 
	  real_read x' y'
      else
	real_read x y
  in
    if !rgb24mode then
      begin
	let img = rgb24 (
	  match OImages.tag img with
	    | Rgb24(_) -> img
	    | Index8(img) -> img#to_rgb24#coerce
	    | Index16(img) -> img#to_rgb24#coerce
	    | _ -> failwith "not supported")
	in
	let imgw,imgh,bx,by,w,h = get_coords img in
	let w' = adjust_width w in
	  write_out ((!target_dir)^dst) (fun stream ->
					   output_header stream src labelname w' h;
					   for y = by to by+h-1 do
					     for x = bx to bx+w'-1 do
					       let color = read img imgw imgh x y {r=0; g=0; b=0} in
					       let res = rgb24_of_rgb24 color in
						 out_long stream res
					     done
					   done)
      end
    else
      if !clut_mode then
	begin
	  let img =
	    match OImages.tag img with
	      | Index8(img) -> img
	      | _ -> failwith "not supported"
	  in
	  let imgw,imgh,bx,by,w,h = get_coords img in
	  let nb_colors = img#size in
	    bpp_clut := 8;
	    let check_index = 
	      let check_mask mask idx =
		assert (idx land mask = idx);
		idx
	      in
		if !opt_clut then
		  if nb_colors <= 2 then
		    begin
		      bpp_clut := 1;
		      check_mask 0x1
		    end
		  else if nb_colors <= 4 then
		    begin
		      bpp_clut := 2;
		      check_mask 0x3
		    end
		  else if nb_colors <= 16 then
		    begin
		      bpp_clut := 4;
		      check_mask 0xf
		    end
		  else check_mask 0xff
		else check_mask 0xff
	    in
	    let w' = adjust_width w in
	    let paldst = name_clut basename in
	      write_out ((!target_dir)^dst) (fun stream ->
					       output_header stream src labelname w' h;
					       let x = ref 0 and value = ref 0 and i = ref 0 in
						 for y = by to by+h-1 do
						   x := bx;
						   while !x < bx+w' do
						     i := 0;
						     value := 0;
						     while !i < (8 / !bpp_clut) do
						       let idx = check_index (read img imgw imgh !x y 0) in
						       let idx = 
							 if !aworld && !bpp_clut = 8 then idx + 16 * (1 + idx / 112)
							 else idx
						       in
							 value := !value lsl (!bpp_clut);
							 value := !value lor idx;
							 incr x;
							 incr i;
						     done;
						     out_byte stream !value;
						   done
						 done);
	      write_out ((!target_dir)^paldst) (fun stream ->
						  let clutlabelname = name_label_clut basename in
						    output_clut_header stream src clutlabelname nb_colors;
						    for i = 0 to nb_colors-1 do
						      let color = img#query_color i in
						      let res = conv color in
							out_word stream res
						    done)
	end
      else
	begin
	  let img = rgb24 (
	    match OImages.tag img with
	      | Rgb24(_) -> img
	      | Index8(img) -> img#to_rgb24#coerce
	      | Index16(img) -> img#to_rgb24#coerce
	      | _ -> failwith "not supported")
	  in
	  let imgw,imgh,bx,by,w,h = get_coords img in
	  let w' = adjust_width w in
	  let dither = Array.make_matrix h w' (0.,0.,0.) in
	  let triple_of_color c = (float_of_int c.r,float_of_int c.g,float_of_int c.b) in
	  let add_triple (x1,y1,z1) (x2,y2,z2) = (x1 +. x2, y1 +. y2, z1 +. z2) in
	  let sub_triple (x1,y1,z1) (x2,y2,z2) = (x1 -. x2, y1 -. y2, z1 -. z2) in
	  let add_error x y err =
	    if 0 <= x && x < w' && 0 <= y && y < h then
	      begin
		dither.(y).(x) <- add_triple (dither.(y).(x)) err
	      end
	  in
	  let spread_error x y (d,matrix) error =
	    let lines = Array.length matrix in
	    let mid_l = (lines / 2) in
	    let columns = Array.length (matrix.(0)) in
	    let mid_c = (columns / 2) in
	    let f c x = ((float_of_int c) *. x) /. (float_of_int d) in
	    let comp_error coef (x,y,z) = (f coef x,f coef y,f coef z) in
	      for j = 0 to lines - 1 do
		for i = 0 to columns - 1 do
		  add_error (x+i-mid_c) (y+j-mid_l) (comp_error (matrix.(j).(i)) error)
		done
	      done
	  in
	  let truncate (r,g,b) = 
	    let aux x = max 0. (min 256. x) in
	      (aux r,aux g,aux b)
	  in
	  let color_of_triple (r,g,b) = 
	    let aux v = max 0 (min 255 (round v))
	    in
	      { r = aux r; g = aux g; b = aux b }
	  in
	  let fix_color x y c =
	    if c.r = 0 && c.g = 0 && c.b = 0 then triple_of_color c
	    else
	      add_triple (triple_of_color c) (dither.(y).(x))
	  in
	  let check_error (er,eg,eb) = 
	    let abs x = if x > 0. then x else -. x in
	    let norm = max (max (abs er) (abs eg)) (abs eb) in
	      prerr_float norm;
	      prerr_string " ";
	  in
	  let update_error x y oldcolor newcolor =
	    let err = sub_triple oldcolor newcolor in
	      spread_error x y filter err
	  in
	  let fix_id x y c = triple_of_color c
	  and upd_void x y oldcolor newcolor = () in
	  let fixc,upde = 
	    if !dithering then fix_color,update_error
	    else fix_id,upd_void
	  in
	    write_out ((!target_dir)^dst) (fun stream ->
					     output_header stream src labelname w' h;
					     for y = by to by+h-1 do
					       for x = bx to bx+w'-1 do
						 let color = read img imgw imgh x y {r = 0; g = 0; b = 0} in
						 let oldcolor = truncate (fixc x y color) in
						 let res = conv (color_of_triple oldcolor) in
						 let newcolor = triple_of_color (invconv res) in
						   upde x y oldcolor newcolor;
						   out_word stream res
					       done;
					     done)
	end

let get_options () =
  let buf = Buffer.create 1 in
  let add_option s = 
    Buffer.add_string buf s; 
    Buffer.add_char buf ' '
  in
    begin
      match !output_format with
	| Rgb16 -> add_option "-rgb"
	| Cry16 -> add_option "-cry"
    end;
    if !dithering then add_option "--dithering"
    else add_option "--no-dithering";
    if !ascii_output then add_option "--ascii"
    else add_option "--binary";
    add_option ("--target-dir "^(!target_dir));
    if !clut_mode then add_option "--clut"
    else add_option "--no-clut";
    if !opt_clut then add_option "--opt-clut"
    else add_option "--no-opt-clut";
    if !mode15bit then add_option "--15-bits"
    else add_option "--16-bits";
    if !rgb24mode then add_option "--true-color"
    else add_option "--reduced-color";
    if !gray then add_option "--gray";
    if !glass then add_option "--glass";
    if !texture then add_option "--texture";
    if !keep_positive && not !keep_negative then add_option "--positive";
    if not !keep_positive && !keep_negative then add_option "--negative";
    if !keep_positive && !keep_negative then add_option "--both";
    if not !gray && not !glass then add_option "--normal";
    if !overwrite then add_option "--overwrite"
    else add_option "--no-overwrite";
    if !rotate then add_option ("--rotate "^(string_of_int !rotate_angle))
    else add_option "--no-rotate";
    if !cut then add_option ("--cut "^(string_of_int !cut_x)^","^(string_of_int !cut_y)^":"^(string_of_int !cut_w)^"x"^(string_of_int !cut_h))
    else add_option "--no-cut";
    if !use_tga2cry then add_option "--use-cry-table"
    else add_option "--compute-cry";
    if !sample then add_option ("--sample "^(string_of_int !sample_w)^"x"^(string_of_int !sample_h))
    else add_option "--no-sample";
    if !aworld then add_option "--aworld"
    else add_option "--no-aworld";
    Buffer.contents buf

let info_string = 
  let prelude = "Jaguar image converter by Seb/The Removers (version "^(Version.version)^")" in
  let option = "Default options: "^(get_options ()) in
    prelude^"\n"^option

let do_cry_conv s = 
  let i = ref 0 in
  let n = String.length s in
  let is_digit = function '0'..'9' -> true | _ -> false in
  let val_digit c = (Char.code c) - (Char.code '0') in
  let digits () = 
    let v = ref 0 in
      while !i < n && is_digit s.[!i] do
	v := 10 * !v + (val_digit (s.[!i]));
	incr i
      done;
      !v
  in
  let skip_comma () = 
    if !i < n && s.[!i] = ',' then incr i
    else failwith "ill-formed r,g,b tuple"
  in
  let red = digits() in
  let _ = skip_comma() in
  let green = digits() in
  let _ = skip_comma() in
  let blue = digits() in
  let cry = cry16_of_rgb24 { r = red; g = green; b = blue } in
    prerr_string (Format.sprintf "cry (%d,%d,%d) = 0x%04x\n" red green blue cry)

let main () =
  let _ = Arg.parse ["-rgb",(Arg.Unit(fun () -> output_format := Rgb16)),"rgb16 output format";
		     "-cry",(Arg.Unit(fun () -> output_format := Cry16)),"cry16 output format";
		     "--dithering",(Arg.Set(dithering)),"enable dithering";
		     "--no-dithering",(Arg.Clear(dithering)),"disable dithering";
		     "--ascii",(Arg.Set(ascii_output)),"source output (same as --assembly)"; 
		     "--assembly",(Arg.Set(ascii_output)),"assembly file"; 
		     "--no-ascii",(Arg.Clear(ascii_output)),"data output (same as --binary)";
		     "--binary",(Arg.Clear(ascii_output)),"binary file";
		     "--target-dir",(Arg.Set_string(target_dir)),"set target directory";
		     "--clut",(Arg.Set(clut_mode)),"clut mode";
		     "--no-clut",(Arg.Clear(clut_mode)),"true color mode";
		     "--opt-clut",(Arg.Set(opt_clut)),"optimise low resolution images";
		     "--no-opt-clut",(Arg.Clear(opt_clut)),"optimise low resolution images";
		     "--15-bits",(Arg.Set(mode15bit)),"15 bits mode";
		     "--16-bits",(Arg.Clear(mode15bit)),"16 bits mode";
		     "--true-color",(Arg.Set(rgb24mode)),"true color mode";
		     "--reduced-color",(Arg.Clear(rgb24mode)),"reduced color mode";
		     "--gray",(Arg.Set(gray)),"gray (CRY intensities)";
		     "--glass",(Arg.Set(glass)),"glass (CRY relative)";
		     "--texture",(Arg.Set(texture)),"texture fixed intensities (CRY)";
		     "--positive",(Arg.Unit(fun () -> keep_negative := false; keep_positive := true)),"keep only positive delta";
		     "--negative",(Arg.Unit(fun () -> keep_negative := true; keep_positive := false)),"keep only negative delta";
		     "--both",(Arg.Unit(fun () -> keep_negative := true; keep_positive := true)),"keep both delta types";
		     "--normal",(Arg.Unit(fun () -> gray := false; glass := false; texture := false)),"normal CRY";
		     "--overwrite",(Arg.Set(overwrite)),"overwrite existing files";
		     "--no-overwrite",(Arg.Clear(overwrite)),"do not overwrite existing files";
		     "--no-rotate",Arg.Clear(rotate),"do not rotate image";
		     "--rotate",Arg.Int(fun n -> rotate := true; rotate_angle := n),"rotate image of ? degrees";
		     "--no-cut",(Arg.Clear(cut)),"do not cut image";
		     "--cut",(Arg.String(analyse_cut_string)),"cut image at given coordinates";
		     "--use-cry-table",(Arg.Set(use_tga2cry)),"use precalculed tga2cry conversion table to get CRY values";
		     "--compute-cry",(Arg.Clear(use_tga2cry)),"really compute CRY values";
		     "--cry-conv",(Arg.String(fun s -> do_cry_conv s)),"interactive cry conversion";
		     "--sample",(Arg.String(analyse_sample_string)),"resample image at given size";
		     "--no-sample",(Arg.Clear(sample)),"no image resampling";
		     "--aworld",(Arg.Set(aworld)),"enable Another World mode (undocumented)";
		     "--no-aworld",(Arg.Clear(aworld)),"disable Another World mode (undocumented)";     
		    ]
	do_file info_string
  in ()

let _ = main ()


