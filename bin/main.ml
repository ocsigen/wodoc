let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let usage () =
  prerr_endline
    "wodoc - an odoc driver for complete styled websites\n\nUsage:\n\  wodoc preprocess <file.mld>\n\      rewrite {%wodoc:..%} -> {%html:<!--wodoc:..-->%}\n\  wodoc render <odoc.html>\n\      turn wodoc markers in odoc HTML into real HTML\n\  wodoc assemble --template <tmpl.html> [--current <id>] [--menu <f>]\n\                 [--subproject <s>] [--menu-current <id>] [--leftnav <f>] <odoc.html>\n\      wrap rendered odoc HTML in a site template\n\  wodoc nav --menu <menu.wiki> --base <b> [--pkg <p>] [--heading <h>]\n\            [--api-map <sub=path;..>]\n\      build a manual's left-column navigation from its wiki menu\n\  wodoc resolve-refs --base <b> --sibling <Mod=seg/seg/..> [--sibling ..] <file>..\n\      link cross-package sibling references (rewrites files in place)\n\  wodoc convert <file.wiki>\n\      best-effort wikicréole -> .mld migration aid (review the output)\n\  wodoc build --config <doc/wodoc> --out <dir> --menu <menu.html|URL> [--label <v>]\n\              [--src <odoc _html>] [--latest] [--local]\n\      turn-key: assemble a whole odoc tree into the themed site from a config\n\      (--menu accepts a local file or an http(s) URL, fetched with curl;\n\       --local also fetches the shared /css//img/ assets for local preview)\n\nExcept resolve-refs and build (which write files), each command writes to stdout.";
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
  | _ :: "nav" :: args -> (
      let flags, _ = parse_args args in
      match List.assoc_opt "base" flags with
      | None -> usage ()
      | Some base -> (
          let heading = List.assoc_opt "heading" flags in
          match
            ( List.assoc_opt "menu" flags
            , List.assoc_opt "api" flags
            , List.assoc_opt "anchors" flags )
          with
          | Some menu_f, _, _ ->
              let pkg = Option.value ~default:"" (List.assoc_opt "pkg" flags) in
              let heading = Option.value ~default:"Manual" heading in
              let api_map =
                match List.assoc_opt "api-map" flags with
                | None -> []
                | Some s ->
                    List.filter_map
                      (fun kv ->
                         match String.index_opt kv '=' with
                         | Some i ->
                             Some
                               ( String.sub kv 0 i
                               , String.sub kv (i + 1) (String.length kv - i - 1) )
                         | None -> None)
                      (String.split_on_char ';' s)
              in
              print_string
                (Wodoc.Nav.manual ~pkg ~heading ~api_map ~base (read_file menu_f))
          | _, Some idx_f, _ ->
              let lib = Option.value ~default:"" (List.assoc_opt "lib" flags) in
              let wrapper =
                Option.value ~default:"" (List.assoc_opt "wrapper" flags)
              in
              let heading = Option.value ~default:"Modules" heading in
              let skip =
                List.filter_map
                  (fun (k, v) -> if k = "skip-title" then Some v else None)
                  flags
              in
              print_string
                (Wodoc.Nav.api ~wrapper ~heading ~skip ~base ~lib
                   (read_file idx_f))
          | _, _, Some menu_f ->
              let heading = Option.value ~default:"Manual" heading in
              print_string (Wodoc.Nav.anchors ~heading ~base (read_file menu_f))
          | None, None, None -> usage ()))
  | _ :: "resolve-refs" :: args ->
      (* rewrites the given files IN PLACE (like the resolve-*.py scripts).
         --hosted selects cross-PROJECT mode (resolve-deps.py); otherwise
         --sibling selects cross-PACKAGE mode (resolve-siblings.py). *)
      let flags, files = parse_args args in
      let base = Option.value ~default:"" (List.assoc_opt "base" flags) in
      let hosted =
        List.filter_map
          (fun (k, v) ->
             if k <> "hosted"
             then None
             else
               match String.split_on_char '=' v with
               | [ pkg; spec ] -> (
                   match String.split_on_char ':' spec with
                   | [ dir; multi; wrapper ] -> Some (pkg, (dir, multi = "true", wrapper))
                   | _ -> None)
               | _ -> None)
          flags
      in
      let transform =
        if hosted <> []
        then
          let relroot =
            Option.value ~default:base (List.assoc_opt "relroot" flags)
          in
          let side = Option.value ~default:"" (List.assoc_opt "side" flags) in
          let self = Option.value ~default:"" (List.assoc_opt "self" flags) in
          Wodoc.Resolve.deps ~hosted ~relroot ~side ~self
        else
          let siblings =
            List.filter_map
              (fun (k, v) ->
                 if k <> "sibling"
                 then None
                 else
                   match String.index_opt v '=' with
                   | None -> None
                   | Some i ->
                       let m = String.sub v 0 i in
                       let segs =
                         List.filter (fun s -> s <> "")
                           (String.split_on_char '/'
                              (String.sub v (i + 1) (String.length v - i - 1)))
                       in
                       Some (m, segs))
              flags
          in
          Wodoc.Resolve.html ~siblings ~base
      in
      List.iter
        (fun f ->
           let src = read_file f in
           let out = transform src in
           if out <> src
           then (
             let oc = open_out_bin f in
             output_string oc out;
             close_out oc))
        files
  | _ :: "build" :: args ->
      let set_latest = List.mem "--latest" args in
      let local = List.mem "--local" args in
      let args = List.filter (fun a -> a <> "--latest" && a <> "--local") args in
      let flags, _ = parse_args args in
      let req k = match List.assoc_opt k flags with Some v -> v | None -> usage () in
      let cfg = req "config" in
      let c = Wodoc.Config.of_string (read_file cfg) in
      let label = Option.value ~default:"dev" (List.assoc_opt "label" flags) in
      (* --src points at a prebuilt odoc _html tree; without it, build it here.
         The build method comes from the config: odoc_driver on the installed
         package for a client/server project (server/client share module names,
         so `dune build @doc` collides), else plain `dune build @doc`. *)
      let src =
        match List.assoc_opt "src" flags with
        | Some s -> s
        | None -> (
            match c.odoc_driver with
            | Some pkg ->
                (* The installed manual .mld carry {%wodoc:%} markers; rewrite
                   them in place to HTML comments (idempotent) so odoc keeps them
                   for Assemble's render pass. Best-effort: skip if the package
                   has no installed odoc-pages. *)
                (let tmp = Filename.temp_file "wodoc-doc" "" in
                 let doc_root =
                   if Sys.command
                        (Printf.sprintf "opam var doc > %s 2>/dev/null"
                           (Filename.quote tmp)) = 0
                   then String.trim (read_file tmp)
                   else ""
                 in
                 (try Sys.remove tmp with _ -> ());
                 let pages =
                   Filename.concat (Filename.concat doc_root pkg) "odoc-pages"
                 in
                 if doc_root <> "" && Sys.file_exists pages
                 then
                   Array.iter
                     (fun e ->
                        if Filename.check_suffix e ".mld"
                        then (
                          let f = Filename.concat pages e in
                          let out = Wodoc.Preprocess.string (read_file f) in
                          let oc = open_out_bin f in
                          output_string oc out; close_out oc))
                     (Sys.readdir pages));
                let work = "_wodoc-html" in
                if Sys.command
                     (Printf.sprintf "odoc_driver %s --remap --html-dir %s"
                        (Filename.quote pkg) (Filename.quote work)) <> 0
                then (prerr_endline "wodoc build: odoc_driver failed"; exit 1);
                Filename.concat work pkg
            | None ->
                let profile =
                  match c.profile with Some p -> " --profile " ^ p | None -> ""
                in
                let manual = if c.doc_manual then " @doc-manual" else "" in
                if Sys.command ("dune build @doc" ^ manual ^ profile) <> 0
                then (prerr_endline "wodoc build: dune build @doc failed"; exit 1);
                "_build/default/_doc/_html")
      in
      Wodoc.Build.run c ~src ~out:(req "out") ~label ~menu:(req "menu")
        ~assets_dir:(Filename.dirname cfg) ~local ~set_latest
  | _ -> usage ()
