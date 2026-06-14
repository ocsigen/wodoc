let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let usage () =
  prerr_endline
    "wodoc - an odoc driver for complete styled websites\n\nUsage:\n\  wodoc preprocess <file.mld>\n\      rewrite {%wodoc:..%} -> {%html:<!--wodoc:..-->%}\n\  wodoc render <odoc.html>\n\      turn wodoc markers in odoc HTML into real HTML\n\  wodoc assemble --template <tmpl.html> [--current <id>] [--menu <f>]\n\                 [--subproject <s>] [--menu-current <id>] [--leftnav <f>]\n\                 [--blog-config <c>] [--blog-base <b>] <odoc.html>\n\      wrap rendered odoc HTML in a site template (--blog-config expands a\n\      {%wodoc:blog-latest%} marker with that blog's latest-posts fragment)\n\  wodoc nav --api <indexdoc> --base <b> --lib <l> [--wrapper <W>] [--heading <h>]\n\            [--skip-title <t>]..\n\      build an API module navigation fragment from a curated odoc index\n\  wodoc resolve-refs --base <b> --sibling <Mod=seg/seg/..> [--sibling ..] <file>..\n\      link cross-package sibling references (rewrites files in place)\n\  wodoc convert <file.wiki>\n\      best-effort wikicréole -> .mld migration aid (review the output)\n\  wodoc build --config <doc/wodoc> --out <dir> --menu <menu.html|URL> [--label <v>]\n\              [--src <odoc _html>] [--latest] [--local] [--mld-dir <d>] [--nav <f>]\n\      turn-key: assemble a whole odoc tree into the themed site from a config\n\      (--menu accepts a local file or an http(s) URL, fetched with curl;\n\       --local also fetches the shared /css//img/ assets for local preview)\n\  wodoc release --site <gh-pages-dir> --version <v> [--from dev]\n\      freeze <site>/<from> as the stable <site>/<version> + repoint `latest`\n\  wodoc blog-nav --config <doc/wodoc> [--base <b>]\n\      the blog's left-nav block (for assemble --leftnav)\n\  wodoc blog-feed --config <doc/wodoc> --base-url <origin> [--blog-path <p>]\n\                  [--feed-path /feed.xml] [--title <t>] [--author <a>]\n\      an Atom feed of the blog posts (syndication, e.g. OCaml Planet)\n\  wodoc requalify-xrefs --site <root> [--wrapped <dir>=<Wrapper>]..\n\      fix flat cross-project links to wrapped libs (Eliom_content -> Eliom/Content)\n\      by probing the co-located target trees under <root>\n\nExcept resolve-refs, build and release (which write files), each command writes to stdout.";
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

(* Resolve a blog's [(dir …)] relative to the config file (like dune paths),
   so it is found regardless of the build script's cwd (e.g. the vitrine builds
   the site home from doc/vitrine but reads the blog declared in doc/blog). *)
let resolve_blog cfg (c : Wodoc.Config.t) =
  match c.blog with
  | Some b when Filename.is_relative b.dir ->
      { c with
        blog = Some {b with dir = Filename.concat (Filename.dirname cfg) b.dir}
      }
  | _ -> c

let config_of cfg = resolve_blog cfg (Wodoc.Config.of_string (read_file cfg))

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
          let page =
            Wodoc.Assemble.page ~preamble ~flat
              ~strip_anchors:(not keep_anchors) ~base ~menu ~subproject
              ~menu_current ~leftnav ~template ~current (read_file file)
          in
          (* --blog-config <doc/blog wodoc>: expand a {%wodoc:blog-latest%} marker
             on this page with the latest-posts fragment of that blog (so a page
             built via the low-level assemble path — e.g. a site home — can carry
             the listing, like `wodoc build` does for the turn-key path).
             --blog-base is the relative path from this page to the blog root. *)
          let page =
            match List.assoc_opt "blog-config" flags with
            | None -> page
            | Some cf -> (
              match (config_of cf).blog with
              | None -> page
              | Some b ->
                  let bbase =
                    Option.value ~default:"" (List.assoc_opt "blog-base" flags)
                  in
                  Wodoc.Blog.expand
                    ~fragment:
                      (Wodoc.Blog.latest_fragment ~base:bbase b
                         (Wodoc.Blog.posts b))
                    page)
          in
          print_string page
      | _ -> usage ())
  | _ :: "nav" :: args -> (
      let flags, _ = parse_args args in
      match List.assoc_opt "base" flags, List.assoc_opt "api" flags with
      | Some base, Some idx_f ->
          let lib = Option.value ~default:"" (List.assoc_opt "lib" flags) in
          let wrapper =
            Option.value ~default:"" (List.assoc_opt "wrapper" flags)
          in
          let heading =
            Option.value ~default:"Modules" (List.assoc_opt "heading" flags)
          in
          let skip =
            List.filter_map
              (fun (k, v) -> if k = "skip-title" then Some v else None)
              flags
          in
          print_string
            (Wodoc.Nav.api ~wrapper ~heading ~skip ~base ~lib (read_file idx_f))
      | _ -> usage ())
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
               | [pkg; spec] -> (
                 match String.split_on_char ':' spec with
                 | [dir; multi; wrapper] ->
                     Some (pkg, (dir, multi = "true", wrapper))
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
                         List.filter
                           (fun s -> s <> "")
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
             output_string oc out; close_out oc))
        files
  | _ :: "build" :: args ->
      let set_latest = List.mem "--latest" args in
      let local = List.mem "--local" args in
      let args =
        List.filter (fun a -> a <> "--latest" && a <> "--local") args
      in
      let flags, _ = parse_args args in
      let req k =
        match List.assoc_opt k flags with Some v -> v | None -> usage ()
      in
      let cfg = req "config" in
      let c = config_of cfg in
      (* per-version overrides: a manual-only project with one config but several
         version directories (e.g. tuto's tutos/<v>/manual, distinct per version)
         passes --mld-dir, and --nav for that version's left navigation (a file in
         the same [(nav …)] syntax as the config stanza), instead of hardcoding. *)
      let c =
        match List.assoc_opt "mld-dir" flags with
        | Some d -> {c with mld_dir = Some d}
        | None -> c
      in
      let c =
        match List.assoc_opt "nav" flags with
        | Some f -> {c with nav = Wodoc.Config.nav_of_string (read_file f)}
        | None -> c
      in
      let label = Option.value ~default:"dev" (List.assoc_opt "label" flags) in
      (* --src points at a prebuilt odoc _html tree; without it, build it here.
         The build method comes from the config: odoc_driver on the installed
         package for a client/server project (server/client share module names,
         so `dune build @doc` collides), else plain `dune build @doc`. *)
      let src =
        match List.assoc_opt "src" flags with
        | Some s -> s
        | None -> (
          match c.mld_dir with
          | Some dir ->
              (* Direct-mld build (manual-only / archived project, no dune @doc):
                   compile every .mld with odoc straight (preprocess -> compile ->
                   link -> html-generate). Output goes under <pkg>/ if a package is
                   set, else at the html root. *)
              let work = "_wodoc-html" in
              let odoc = Filename.concat work "odoc" in
              let html = Filename.concat work "html" in
              List.iter
                (fun d ->
                   ignore
                     (Sys.command
                        (Printf.sprintf "mkdir -p %s" (Filename.quote d))))
                [odoc; html];
              let pkg_flag =
                if c.mld_package = ""
                then ""
                else " --package " ^ Filename.quote c.mld_package
              in
              let mlds =
                Sys.readdir dir |> Array.to_list
                |> List.filter (fun e -> Filename.check_suffix e ".mld")
                |> List.sort compare
              in
              if mlds = []
              then (
                prerr_endline ("wodoc build: no .mld in " ^ dir);
                exit 1);
              List.iter
                (fun e ->
                   let name = Filename.remove_extension e in
                   let pp = Filename.concat odoc ("pp-" ^ e) in
                   (let oc = open_out_bin pp in
                    output_string oc
                      (Wodoc.Preprocess.string
                         (read_file (Filename.concat dir e)));
                    close_out oc);
                   let odocf =
                     Filename.concat odoc ("page-" ^ name ^ ".odoc")
                   in
                   let odoclf =
                     Filename.concat odoc ("page-" ^ name ^ ".odocl")
                   in
                   let cmd =
                     Printf.sprintf
                       "odoc compile %s%s -I %s -o %s && odoc link %s -I %s -o %s && odoc html-generate %s -o %s"
                       (Filename.quote pp) pkg_flag (Filename.quote odoc)
                       (Filename.quote odocf) (Filename.quote odocf)
                       (Filename.quote odoc) (Filename.quote odoclf)
                       (Filename.quote odoclf) (Filename.quote html)
                   in
                   if Sys.command cmd <> 0
                   then (
                     prerr_endline ("wodoc build: odoc failed on " ^ e);
                     exit 1))
                mlds;
              if c.mld_package = ""
              then html
              else Filename.concat html c.mld_package
          | None -> (
            match c.odoc_driver with
            | Some pkg ->
                (* [pkg] is a space-separated list of opam packages to document
                   (e.g. "js_of_ocaml js_of_ocaml-lwt …" for a multi-package
                   project; one name for a single-package one). odoc_driver
                   documents them all (+ their deps) and --remaps the rest to
                   ocaml.org. The FIRST package is the main one: its subtree
                   holds the manual and is what the site is assembled around. *)
                let pkgs =
                  List.filter (fun s -> s <> "") (String.split_on_char ' ' pkg)
                in
                let main_pkg = match pkgs with p :: _ -> p | [] -> pkg in
                (* The installed manual .mld carry {%wodoc:%} markers; rewrite
                   them in place to HTML comments (idempotent) so odoc keeps them
                   for Assemble's render pass. Best-effort: skip a package that
                   has no installed odoc-pages. *)
                (let tmp = Filename.temp_file "wodoc-doc" "" in
                 let doc_root =
                   if
                     Sys.command
                       (Printf.sprintf "opam var doc > %s 2>/dev/null"
                          (Filename.quote tmp))
                     = 0
                   then String.trim (read_file tmp)
                   else ""
                 in
                 (try Sys.remove tmp with _ -> ());
                 if doc_root <> ""
                 then
                   List.iter
                     (fun p ->
                        let pages =
                          Filename.concat (Filename.concat doc_root p)
                            "odoc-pages"
                        in
                        if Sys.file_exists pages
                        then
                          Array.iter
                            (fun e ->
                               if Filename.check_suffix e ".mld"
                               then (
                                 let f = Filename.concat pages e in
                                 let out =
                                   Wodoc.Preprocess.string (read_file f)
                                 in
                                 let oc = open_out_bin f in
                                 output_string oc out; close_out oc))
                            (Sys.readdir pages))
                     pkgs);
                (* Interactive examples (toplevel, demos) are a dune alias, not
                   something odoc_driver produces. When the project ships them
                   (doc_manual), build @doc-manual so its assets land in
                   _build/default/manual/files for Build.run's manual_files copy. *)
                (if c.doc_manual
                 then
                   let profile =
                     match c.profile with
                     | Some p -> " --profile " ^ p
                     | None -> ""
                   in
                   if Sys.command ("dune build @doc-manual" ^ profile) <> 0
                   then (
                     prerr_endline "wodoc build: dune build @doc-manual failed";
                     exit 1));
                let work = "_wodoc-html" in
                if
                  Sys.command
                    (* [pkg] is the space-separated package list, passed as
                       several args (not quoted as one). *)
                    (Printf.sprintf "odoc_driver %s --remap --html-dir %s" pkg
                       (Filename.quote work))
                  <> 0
                then (
                  prerr_endline "wodoc build: odoc_driver failed";
                  exit 1);
                (* Multi-package: each package lands in its own _wodoc-html/<pkg>
                   subtree, so assemble from the root and let (packages …) pick
                   the subtrees. Single-package (no (packages …)): everything is
                   under _wodoc-html/<pkg>, so point straight at it. *)
                if c.packages <> [] then work else Filename.concat work main_pkg
            | None ->
                let profile =
                  match c.profile with
                  | Some p -> " --profile " ^ p
                  | None -> ""
                in
                let manual = if c.doc_manual then " @doc-manual" else "" in
                if Sys.command ("dune build @doc" ^ manual ^ profile) <> 0
                then (
                  prerr_endline "wodoc build: dune build @doc failed";
                  exit 1);
                "_build/default/_doc/_html"))
      in
      Wodoc.Build.run c ~src ~out:(req "out") ~label ~menu:(req "menu")
        ~assets_dir:(Filename.dirname cfg) ~local ~set_latest
  | _ :: "requalify-xrefs" :: args ->
      (* Post-pass over a co-located multi-project site: rewrite flat
         cross-project links to a wrapped library (Eliom_content) into the
         qualified path the target deploys (Eliom/Content), probing the tree. *)
      let flags, _ = parse_args args in
      let site =
        match List.assoc_opt "site" flags with Some s -> s | None -> usage ()
      in
      let wrapped =
        List.filter_map
          (fun (k, v) ->
             if k = "wrapped"
             then
               match String.index_opt v '=' with
               | Some i ->
                   Some
                     ( String.sub v 0 i
                     , String.sub v (i + 1) (String.length v - i - 1) )
               | None -> None
             else None)
          flags
      in
      let rec walk f dir =
        Array.iter
          (fun e ->
             let p = Filename.concat dir e in
             if try Sys.is_directory p with _ -> false
             then walk f p
             else if Filename.check_suffix p ".html"
             then f p)
          (try Sys.readdir dir with _ -> [||])
      in
      let count = ref 0 in
      walk
        (fun p ->
           let dir = Filename.dirname p in
           let exists href =
             let href =
               match String.index_opt href '#' with
               | Some i -> String.sub href 0 i
               | None -> href
             in
             if href = ""
             then false
             else
               let tgt =
                 if href.[0] = '/'
                 then
                   Filename.concat site
                     (String.sub href 1 (String.length href - 1))
                 else Filename.concat dir href
               in
               Sys.file_exists tgt
               || Sys.file_exists (tgt ^ ".html")
               || Sys.file_exists (Filename.concat tgt "index.html")
           in
           let s = read_file p in
           let out = Wodoc.Resolve.requalify ~wrapped ~exists s in
           if out <> s
           then (
             let oc = open_out_bin p in
             output_string oc out; close_out oc; incr count))
        site;
      Printf.eprintf "wodoc requalify-xrefs: rewrote %d files\n" !count
  | _ :: "release" :: args ->
      let flags, _ = parse_args args in
      let req k =
        match List.assoc_opt k flags with Some v -> v | None -> usage ()
      in
      let from = Option.value ~default:"dev" (List.assoc_opt "from" flags) in
      Wodoc.Build.release ~site:(req "site") ~from ~version:(req "version")
  | _ :: "blog-nav" :: args -> (
      (* the blog's left-nav block, for the low-level assemble path (--leftnav) *)
      let flags, _ = parse_args args in
      match List.assoc_opt "config" flags with
      | None -> usage ()
      | Some cfg -> (
        match (config_of cfg).blog with
        | None -> ()
        | Some b ->
            let base = Option.value ~default:"" (List.assoc_opt "base" flags) in
            print_string (Wodoc.Blog.nav_html ~base b (Wodoc.Blog.posts b))))
  | _ :: "blog-feed" :: args -> (
      (* an Atom feed of the blog posts (syndication, e.g. OCaml Planet) *)
      let flags, _ = parse_args args in
      let req k =
        match List.assoc_opt k flags with Some v -> v | None -> usage ()
      in
      let cfg = req "config" in
      match (config_of cfg).blog with
      | None -> ()
      | Some b ->
          let base_url = req "base-url" in
          let blog_path =
            Option.value ~default:"" (List.assoc_opt "blog-path" flags)
          in
          let feed_path =
            Option.value ~default:"/feed.xml" (List.assoc_opt "feed-path" flags)
          in
          let title =
            Option.value ~default:"Blog" (List.assoc_opt "title" flags)
          in
          let author =
            Option.value ~default:"" (List.assoc_opt "author" flags)
          in
          print_string
            (Wodoc.Blog.feed ~base_url ~blog_path ~feed_path ~title ~author
               (Wodoc.Blog.posts b)))
  | _ -> usage ()
