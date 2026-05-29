let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let usage () =
  prerr_endline
    "wodoc - an odoc driver for complete styled websites\n\nUsage:\n\  wodoc preprocess <file.mld>   rewrite {%wodoc:..%} -> {%html:<!--wodoc:..-->%}\n\  wodoc render <odoc.html>      turn wodoc markers in odoc HTML into real HTML\n\nEach command reads the file and writes the result to stdout.";
  exit 2

let () =
  match Array.to_list Sys.argv with
  | _ :: "preprocess" :: file :: _ ->
      print_string (Wodoc.Preprocess.string (read_file file))
  | _ :: "render" :: file :: _ ->
      print_string (Wodoc.Render.html (read_file file))
  | _ -> usage ()
