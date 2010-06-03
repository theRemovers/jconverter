open Ocamlbuild_plugin
open Command
open Unix

let version = "0.1.8"

let time =
  let tm = Unix.gmtime (Unix.time ()) in
    Printf.sprintf "%02d/%02d/%04d %02d:%02d:%02d UTC"
      (tm.tm_mon + 1) tm.tm_mday (tm.tm_year + 1900)
      tm.tm_hour tm.tm_min tm.tm_sec

let make_version _ _ =
  let cmd =
    Printf.sprintf "let version = %S\nlet compile_time = %S" version time
  in
    Cmd (S [ A "echo"; Quote (Sh cmd); Sh ">"; P "version.ml" ])

let () = dispatch begin function
  | After_rules ->
      rule "version.ml" ~prod: "version.ml" make_version;
      ocaml_lib ~extern:true ~dir:"+camlimages" "camlimages";
  | _ -> ()
end

