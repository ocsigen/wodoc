let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let usage () =
  prerr_endline
    "wodoc - an odoc driver for complete styled websites\n\nUsage:\n\  wodoc preprocess <file.mld>\n\      rewrite {%wodoc:..%} -> {%html:<!--wodoc:..-->%}\n\  wodoc render <odoc.html>\n\      turn wodoc markers in odoc HTML into real HTML\n\  wodoc assemble --template <tmpl.html> [--current <id>] <odoc.html>\n\      wrap rendered odoc HTML in a site template\n\nEach command writes the result to stdout.";
  exit 2

(* minimal flag parser: returns (assoc of --flag value, positional args) *)
let parse_args args =
  let rec go flags pos = function
    | f :: v :: rest when String.length f > 2 && String.sub f 0 2 = "--" ->
        go ((String.sub f 2 (String.length f - 2), v) :: flags) pos rest
    | a :: rest -> go flags (a :: pos) rest
    | [] -> flags, List.rev pos
  in
  go [] [] args

let () =
  match Array.to_list Sys.argv with
  | _ :: "convert" :: args -> (
      let odoc_refs = List.mem "--odoc-refs" args in
      let args = List.filter (fun a -> a <> "--odoc-refs") args in
      let flags, pos = parse_args args in
      match pos with
      | file :: _ ->
          let default_side =
            Option.value ~default:"" (List.assoc_opt "api-side" flags)
          in
          print_string
            (Wodoc.Convert.wiki_to_mld ~default_side ~odoc_refs (read_file file))
      | [] -> usage ())
  | _ :: "preprocess" :: file :: _ ->
      print_string (Wodoc.Preprocess.string (read_file file))
  | _ :: "render" :: args -> (
      let strip_anchors = List.mem "--strip-anchors" args in
      match
        List.filter
          (fun a -> not (String.length a > 2 && String.sub a 0 2 = "--"))
          args
      with
      | file :: _ ->
          print_string (Wodoc.Render.html ~strip_anchors (read_file file))
      | [] -> usage ())
  | _ :: "assemble" :: args -> (
      let preamble = not (List.mem "--no-preamble" args) in
      let flat = List.mem "--flat" args in
      let keep_anchors = List.mem "--keep-anchors" args in
      let bools = ["--no-preamble"; "--flat"; "--keep-anchors"] in
      let args = List.filter (fun a -> not (List.mem a bools)) args in
      let flags, pos = parse_args args in
      match List.assoc_opt "template" flags, pos with
      | Some tmpl, file :: _ ->
          let current =
            Option.value ~default:"" (List.assoc_opt "current" flags)
          in
          let base = Option.value ~default:"" (List.assoc_opt "base" flags) in
          let menu =
            match List.assoc_opt "menu" flags with
            | Some f -> read_file f
            | None -> ""
          in
          let subproject =
            Option.value ~default:"" (List.assoc_opt "subproject" flags)
          in
          let menu_current =
            Option.value ~default:"" (List.assoc_opt "menu-current" flags)
          in
          let leftnav =
            match List.assoc_opt "leftnav" flags with
            | Some f -> read_file f
            | None -> ""
          in
          let template = read_file tmpl in
          print_string
            (Wodoc.Assemble.page ~preamble ~flat
               ~strip_anchors:(not keep_anchors) ~base ~menu ~subproject
               ~menu_current ~leftnav ~template ~current (read_file file))
      | _ -> usage ())
  | _ -> usage ()
