(* The declarative wodoc project configuration: one [doc/wodoc] file per project
   replaces its build.sh and its menu.wiki. Read by {!Build}. *)

type entry =
  { label : string  (** visible text *)
  ; path : string
    (** href: relative to the version root (filled with base), unless it is
          absolute ([/…]) or a URL ([http(s)://…]), which is emitted verbatim *)
  ; current : string  (** data-wodoc-page id (highlighted on its own pages) *)
  }

(* A nav item is parameterised by what a page tree holds: the config declares
   page trees by their index page ([string item]); {!Build.run} expands them
   into links and groups, leaving [expanded item]s, where no page tree can
   remain since [expanded] has no value. *)
type 'tree item =
  | Link of entry
  | Group of 'tree group
  | Page_tree of 'tree
  (** [(page-tree [<index>])]: the page tree odoc builds from the manual's
          directories ([odoc-pages/<dir>/], ordered by [@children_order]), below
          the page [<index>] (default [index.html]), as odoc_driver writes it
          in [sidebar.json], without its library and source entries. Expanded
          before rendering, so the left column follows the same tree as
          ocaml.org. *)

and 'tree group =
  { heading : string
  ; index : string option
    (** the page the heading links to (a directory of a page tree whose index
          page is clickable), relative to the version root *)
  ; items : 'tree item list }
(** a sub-heading ([<h4>]) and its nested items, one indent level deeper. Lets
    a manual nav reproduce a multi-level menu (sections, subsections, page
    links), as the old wikicréole menu expressed with [==]/[===]. *)

type expanded = |

type 'tree section =
  { heading : string  (** the [<h3>] label of this left-nav block *)
  ; api : bool
    (** [api-section] -> class "api-nav"; else "api-nav manual-nav" *)
  ; items : 'tree item list }

(* How the [llms.txt] index presents the project to AIs, when the defaults do
   not fit: [(llms [(title <t>)] [(summary <s>)])]. *)
type llms =
  { llms_title : string option
    (** the index's [# title]; default: the [(title …)] label, which is short
          because the site shows it by its logo *)
  ; llms_summary : string option
    (** the index's [>] summary; default: the first paragraph of the landing
          page *)
  }

type blog =
  { dir : string
    (** directory of post sources, named [YYYY-MM-DD-slug.mld] (the date is the
          publication date; posts sort newest-first on it). Relative to the config
          file's directory. The posts are plain [.mld] (author from [@author]). *)
  ; out : string
    (** output subdirectory under the version root, e.g. "blog": posts deploy as
          [<out>/blog/<slug>.html] *)
  ; heading : string
    (** the generated left-nav section [<h3>] label, e.g. "Blog" *)
  ; latest : int
    (** how many recent posts the [{%wodoc:blog-latest%}] marker expands to on the
          landing page *)
  }
(** an ultra-simple blog: a directory of dated [.mld] posts that wodoc builds like
    any other page, auto-listing them in a generated left-nav section and exposing
    the most recent ones to the landing via the [{%wodoc:blog-latest%}] marker.
    Generic (no project hardcoding); [None] when the project declares no [(blog …)]. *)

type variant =
  { key : string
    (** e.g. "server": body class [wodoc-server], switch class
          [wodoc-variant-server], notice class [wodoc-variant-notice-server] *)
  ; lib : string  (** odoc subtree dir / [Nav.api ~lib], e.g. "eliom.server" *)
  ; indexdoc : string  (** curated index path (relative to the build cwd) *)
  ; heading : string  (** API-nav heading + switch label, e.g. "Server API" *)
  ; wrapper : string
    (** [Nav.api ~wrapper] / page wrapper module, e.g. "Eliom" *)
  ; skip : string list  (** section titles to omit (Nav.api ~skip) *)
  ; note : string
    (** plain text added to the variant notice of its pages, e.g. "This code
          runs in the browser."; "" for none *)
  }
(** one variant of the API of a package whose libraries share module names:
    the [eliom.server] and [eliom.client] libraries of Eliom, say, or
    [foo.unix] and [foo.js]. Its curated index becomes a section-grouped module
    nav (via {!Nav.api}); it also drives a body class ([wodoc-<key>]), a link
    of the variant switch and a notice at the top of each of its pages. *)

type t =
  { project : string  (** package / project id, e.g. "ocsipersist" *)
  ; title : string  (** sub-project label by the logo, e.g. "Ocsipersist" *)
  ; url_prefix : string
    (** absolute URL path the site is published at, e.g. "/ocsipersist"; used by
          the version selector to switch versions *)
  ; menu_current : string  (** project id highlighted in the shared top menu *)
  ; packages : string list  (** odoc output subtrees to assemble, in order *)
  ; landing : string
    (** index.html redirect target, e.g. "ocsipersist/index.html" *)
  ; highlight : string option  (** project highlight.js to ship, if any *)
  ; profile : string option  (** dune build profile (e.g. "release") *)
  ; odoc_driver : string option
    (** when set, build the API with [odoc_driver <pkg> --remap] (the engine
          ocaml.org uses) instead of [dune build @doc]: needed for a package
          whose libraries share module names ([(variants …)], e.g.
          [eliom.server]/[eliom.client]), which would collide under
          [dune build @doc]. *)
  ; doc_manual : bool  (** also build the [@doc-manual] alias (examples) *)
  ; manual_files : string option
    (** package dir to receive manual/files (examples, images) *)
  ; siblings : (string * string list) list  (** resolve-refs sibling table *)
  ; nav : string section list option
    (** the [(nav …)] stanza; [None] when the config has none: the left
          column then shows the manual tree odoc builds, as
          [(nav (section <title> (page-tree)))] would, if odoc_driver wrote its
          [sidebar.json] *)
  ; variants : variant list
    (** when non-empty, the API comes in variants: instead of one nav from
          [nav], wodoc builds a per-variant API nav from each variant's curated
          index, shows a variant switch, and colours the body by variant. The
          manual nav is shared, taken from [nav]'s manual ([(section …)])
          blocks. *)
  ; hosted : (string * (string * Resolve.layout * string)) list
    (** cross-project resolve-refs table (resolve-refs --hosted): package ->
          (deploy dir, layout, wrapper module). Rewrites sibling Ocsigen
          projects' [ocaml.org] xrefs to relative links into their wodoc docs.
          See {!Resolve.layout} for the layout token (multilib/root/subdir). *)
  ; manual_root : bool
    (** deploy the package's pages at the version ROOT instead of under a
          [<package>/] subdirectory: strip the leading [<package>/] segment from
          output paths, the landing and the nav links. Makes a single-package
          [dune build @doc] project (ocsigenserver, i18n) match the layout of
          odoc-driver projects (eliom: manual at the version root, e.g.
          [/ocsigenserver/latest/config.html]) so cross-project links resolve.
          The package's internal relative links are preserved (the same prefix
          is stripped from every page). *)
  ; mld_dir : string option
    (** direct-mld build (a manual-only / archived project with no [dune build
          @doc]): compile every [.mld] in this dir straight with odoc (preprocess
          -> compile -> link -> html-generate). The pages are the manual; the
          landing [index.html] is a real page (no redirect). *)
  ; mld_package : string
    (** odoc [--package] for the direct-mld compile (the src subtree) *)
  ; flat : bool
    (** assemble [--flat] (content straddling odoc's preamble boundary) *)
  ; static_copy : (string * string) list
    (** verbatim copies into the output: (source path, dest under <out>), e.g.
          a frozen API snapshot, or a manual image *)
  ; blog : blog option  (** an optional [(blog …)] section (see {!type:blog}) *)
  ; markdown : bool
    (** emit the Markdown twin of every page + the [llms.txt]/[llms-full.txt]
          index (for AI/LLM consumption). On by default; [(markdown false)] turns
          it off. *)
  ; css : string list
    (** stylesheet hrefs for the page [<head>]. Each is emitted verbatim when
          absolute ([/…]) or a URL, else made per-page relative ([{{base}}/…]) and,
          when it names a file next to the config, copied into the output, so a
          project can ship a self-contained theme that works at any deploy path.
          [[]] (the default) ships wodoc's built-in default theme as [wodoc.css]. *)
  ; llms : llms  (** the [(llms …)] stanza (see {!type:llms}) *) }

(* A stanza wodoc does not read is an error, not silently ignored: a typo, or a
   stanza left over from an older wodoc, would otherwise drop a setting with no
   warning (a (pub …) left in place of (url-prefix …), for one, kept building
   with the default prefix). The retired stanzas carry a hint. *)
let retired_stanzas =
  [ "pub", "it is now (url-prefix ...)"
  ; "anchor-menu", "declare the left navigation with (nav ...)"
  ; "manual-menu", "declare the left navigation with (nav ...)"
  ; "client-server", "it is now (variants (variant <key> ...) ...)" ]

(* [check_keys ~where known items] raises [Sexp.Error] on the first [(key …)] of
   [items] whose key is not in [known], with the hint [retired] gives for it,
   if any. Bare atoms are left alone. *)
let check_keys ?(retired = []) ~where known items =
  List.iter
    (function
      | Sexp.List (Atom k :: _) when List.mem k known -> ()
      | Sexp.List (Atom k :: _) ->
          let hint =
            match List.assoc_opt k retired with
            | Some h -> h
            | None -> "expected one of: " ^ String.concat ", " known
          in
          raise
            (Sexp.Error
               (Printf.sprintf "unknown stanza (%s ...) in %s: %s" k where hint))
      | Sexp.List _ ->
          raise (Sexp.Error (Printf.sprintf "malformed stanza in %s" where))
      | Sexp.Atom _ -> ())
    items

let parse_entry = function
  | Sexp.List [Atom label; Atom path; Atom current] -> {label; path; current}
  | Sexp.List [Atom label; Atom path] -> {label; path; current = ""}
  | _ -> raise (Sexp.Error "bad (link <label> <path> [<current>]) entry")

(* a nav section body: a flat list of [(link …)], nested [(group …)] blocks and
   [(page-tree …)] placeholders. Stray atoms are ignored; any other list is an
   error (see {!check_keys}). *)
let rec parse_items items =
  check_keys ~where:"a (nav ...) section" ["link"; "group"; "page-tree"] items;
  List.filter_map
    (function
      | Sexp.List (Atom "link" :: rest) -> Some (Link (parse_entry (List rest)))
      | Sexp.List (Atom "group" :: Atom heading :: rest) ->
          Some (Group {heading; index = None; items = parse_items rest})
      | Sexp.List (Atom "group" :: _) ->
          raise (Sexp.Error "bad (group <heading> ...) entry")
      | Sexp.List [Atom "page-tree"] -> Some (Page_tree "index.html")
      | Sexp.List [Atom "page-tree"; Atom index] -> Some (Page_tree index)
      | Sexp.List (Atom "page-tree" :: _) ->
          raise (Sexp.Error "bad (page-tree [<index page>]) entry")
      | _ -> None)
    items

let parse_section api = function
  | Sexp.List (Atom heading :: items) ->
      {heading; api; items = parse_items items}
  | _ -> raise (Sexp.Error "bad nav section")

let parse_nav_blocks blocks =
  check_keys ~where:"(nav ...)" ["section"; "api-section"] blocks;
  List.filter_map
    (function
      | Sexp.List (Atom "section" :: rest) ->
          Some (parse_section false (List rest))
      | Sexp.List (Atom "api-section" :: rest) ->
          Some (parse_section true (List rest))
      | _ -> None)
    blocks

let parse_nav stanzas =
  match Sexp.fields "nav" stanzas with
  | blocks :: _ -> Some (parse_nav_blocks blocks)
  | [] -> None

(* parse a standalone [(nav …)] file (the [--nav <file>] per-version override),
   reusing the same syntax as the [(nav …)] stanza inside a [doc/wodoc] config. A
   file without one (an empty file) declares an empty nav. *)
let nav_of_string s = Some (Option.value ~default:[] (parse_nav (Sexp.parse s)))

let parse_siblings stanzas =
  List.filter_map
    (function
      | [Sexp.Atom m; Sexp.Atom segs] ->
          Some
            (m, List.filter (fun s -> s <> "") (String.split_on_char '/' segs))
      | _ -> None)
    (Sexp.fields "sibling" stanzas)

(* The keys a variant cannot take: its classes, [wodoc-<key>] on the body and
   [wodoc-variant-<key>] on its switch link, would clash with wodoc's own. *)
let reserved_variant_keys =
  [ "attr"
  ; "blog"
  ; "doc"
  ; "header"
  ; "highlight"
  ; "html"
  ; "md"
  ; "menu"
  ; "notice"
  ; "page"
  ; "sf"
  ; "switch"
  ; "version" ]

(* A variant key names CSS classes and a JS value: a lowercase identifier. *)
let is_variant_key k =
  k <> ""
  && (match k.[0] with 'a' .. 'z' -> true | _ -> false)
  && String.for_all
       (function 'a' .. 'z' | '0' .. '9' | '_' -> true | _ -> false)
       k

(* (variants (variant server (lib ..) [(indexdoc ..)] [(heading ..)]
                          [(wrapper ..)] [(skip ..)..] [(note ..)])
             (variant client ..) ..) *)
let parse_variants stanzas =
  let fail fmt = Printf.ksprintf (fun s -> raise (Sexp.Error s)) fmt in
  let no_atom ~where items =
    List.iter
      (function
        | Sexp.Atom a -> fail "%s: unexpected %s" where a | Sexp.List _ -> ())
      items
  in
  (* the atom of [(name a)], if [fields] has it *)
  let atom_field ~where name fields =
    match Sexp.fields name fields with
    | [] -> None
    | [[Sexp.Atom a]] -> Some a
    | _ -> fail "%s: (%s ...) takes one atom, once" where name
  in
  let variant = function
    | Sexp.Atom key :: fields ->
        let where = Printf.sprintf "(variants (variant %s ...))" key in
        if not (is_variant_key key)
        then fail "%s: a key is a lowercase identifier, such as server" where;
        if List.mem key reserved_variant_keys
        then fail "%s: %s is reserved for wodoc's own classes" where key;
        check_keys ~where
          ["lib"; "indexdoc"; "heading"; "wrapper"; "skip"; "note"]
          fields;
        no_atom ~where fields;
        let opt name default =
          Option.value ~default (atom_field ~where name fields)
        in
        { key
        ; lib =
            (match atom_field ~where "lib" fields with
            | Some l -> l
            | None -> fail "%s: missing (lib ...)" where)
        ; indexdoc = opt "indexdoc" ""
        ; heading = opt "heading" key
        ; wrapper = opt "wrapper" ""
        ; skip = Sexp.field_atoms "skip" fields
        ; note = opt "note" "" }
    | _ ->
        fail
          "(variants (variant ...)): expected a key first, e.g. (variant server (lib ...) ...)"
  in
  match Sexp.fields "variants" stanzas with
  | [] -> []
  | _ :: _ :: _ -> fail "(variants ...) appears more than once"
  | [block] ->
      check_keys ~where:"(variants ...)" ["variant"] block;
      no_atom ~where:"(variants ...)" block;
      let variants = List.map variant (Sexp.fields "variant" block) in
      if variants = [] then fail "(variants ...) lists no (variant ...)";
      let rec check_unique : variant list -> unit = function
        | [] -> ()
        | v :: rest ->
            if List.exists (fun (w : variant) -> w.key = v.key) rest
            then fail "(variants ...): %s is declared twice" v.key;
            check_unique rest
      in
      check_unique variants; variants

(* (hosted (eliom eliom multilib Eliom) (ocsigenserver ocsigenserver root "")
          (js_of_ocaml js_of_ocaml subdir "") ..)
   The layout token also accepts the legacy [true]/[false] (= multilib/root). *)
let parse_hosted stanzas =
  match Sexp.fields "hosted" stanzas with
  | block :: _ ->
      List.filter_map
        (function
          | Sexp.List (Atom pkg :: Atom dir :: rest) ->
              let layout =
                match rest with
                | Sexp.Atom m :: _ -> Resolve.layout_of_string m
                | _ -> Resolve.Root
              in
              let wrapper =
                match rest with _ :: Sexp.Atom w :: _ -> w | _ -> ""
              in
              Some (pkg, (dir, layout, wrapper))
          | _ -> None)
        block
  | [] -> []

(* (llms [(title <t>)] [(summary <s>)]), at most one. A value is one string,
   quoted when it holds spaces: an unquoted multi-word value would otherwise
   lose all but its first word, with no warning. Its runs of whitespace (the
   line breaks of a long summary) become single spaces, since llms.txt gives
   each value one line. *)
let parse_llms stanzas =
  let one_line s =
    String.split_on_char ' '
      (String.map (function '\n' | '\r' | '\t' -> ' ' | c -> c) s)
    |> List.filter (fun w -> w <> "")
    |> String.concat " "
  in
  let value key fields =
    match Sexp.fields key fields with
    | [] -> None
    | [[Sexp.Atom v]] -> Some (one_line v)
    | _ ->
        raise
          (Sexp.Error
             (Printf.sprintf
                "(llms (%s ...)) takes one string, given once: quote a value that holds spaces"
                key))
  in
  match Sexp.fields "llms" stanzas with
  | [] -> {llms_title = None; llms_summary = None}
  | [fields] ->
      if
        List.exists
          (function Sexp.Atom _ -> true | Sexp.List _ -> false)
          fields
      then
        raise (Sexp.Error "(llms ...) takes (title ...) and (summary ...) only");
      check_keys ~where:"(llms ...)" ["title"; "summary"] fields;
      {llms_title = value "title" fields; llms_summary = value "summary" fields}
  | _ -> raise (Sexp.Error "the config has more than one (llms ...) stanza")

(* (blog (dir <d>) [(out <o>)] [(heading <h>)] [(latest <n>)]) — at most one *)
let parse_blog stanzas =
  match Sexp.fields "blog" stanzas with
  | fields :: _ ->
      check_keys ~where:"(blog ...)" ["dir"; "out"; "heading"; "latest"] fields;
      let latest =
        match
          int_of_string_opt (Sexp.field_atom_default "latest" "5" fields)
        with
        | Some n -> n
        | None -> 5
      in
      Some
        { dir = Sexp.field_atom_default "dir" "blog" fields
        ; out = Sexp.field_atom_default "out" "blog" fields
        ; heading = Sexp.field_atom_default "heading" "Blog" fields
        ; latest }
  | [] -> None

(* (static-copy <src> <dest>) ...  — repeatable *)
(* The destination is replaced on every build (so a rebuild in the same output
   does not nest the copy inside the previous one), so it must name a path
   strictly inside the version directory: relative, with no [.] or [..]
   segment. *)
let check_static_dest dest =
  let segs = String.split_on_char '/' dest in
  if
    dest = ""
    || (not (Filename.is_relative dest))
    || List.exists (fun s -> s = "" || s = "." || s = "..") segs
  then
    raise
      (Sexp.Error
         (Printf.sprintf
            "bad (static-copy ...) destination %S: expected a relative path inside the version directory, with no . or .. segment"
            dest));
  dest

let parse_static_copy stanzas =
  List.map
    (function
      | [Sexp.Atom src; Sexp.Atom dest] -> src, check_static_dest dest
      | [Sexp.Atom src] -> src, check_static_dest (Filename.basename src)
      | _ -> raise (Sexp.Error "bad (static-copy <src> [<dest>]) entry"))
    (Sexp.fields "static-copy" stanzas)

(* the top-level stanzas {!of_string} reads *)
let stanza_names =
  [ "project"
  ; "title"
  ; "url-prefix"
  ; "menu-current"
  ; "packages"
  ; "landing"
  ; "highlight"
  ; "profile"
  ; "odoc-driver"
  ; "doc-manual"
  ; "manual-files"
  ; "sibling"
  ; "nav"
  ; "variants"
  ; "hosted"
  ; "manual-root"
  ; "mld-dir"
  ; "mld-package"
  ; "flat"
  ; "static-copy"
  ; "blog"
  ; "markdown"
  ; "llms"
  ; "css" ]

let of_string s =
  let stanzas = Sexp.parse s in
  check_keys ~retired:retired_stanzas ~where:"the config" stanza_names stanzas;
  let project =
    match Sexp.field_atom "project" stanzas with
    | Some p -> p
    | None -> raise (Sexp.Error "missing (project ...)")
  in
  let variants = parse_variants stanzas in
  (* a project with variants is built with odoc_driver (they share module
     names, so [dune build @doc] would collide): imply [(odoc-driver <project>)]
     when it is omitted, so the project only declares [(variants …)]. *)
  let odoc_driver =
    match Sexp.field_atom "odoc-driver" stanzas with
    | Some _ as d -> d
    | None -> if variants = [] then None else Some project
  in
  (* (mld-dir <dir> [<package>]): direct-mld build of a directory of [.mld] pages;
     the optional second atom is the odoc [--package]. When the dir is supplied on
     the CLI ([--mld-dir], for a per-version manual) the package is still taken
     from a standalone [(mld-package <pkg>)]. *)
  let mld_dir, mld_package =
    match Sexp.fields "mld-dir" stanzas with
    | (Sexp.Atom dir :: Sexp.Atom pkg :: _) :: _ -> Some dir, pkg
    | (Sexp.Atom dir :: _) :: _ ->
        Some dir, Sexp.field_atom_default "mld-package" "" stanzas
    | _ -> None, Sexp.field_atom_default "mld-package" "" stanzas
  in
  { project
  ; title = Sexp.field_atom_default "title" project stanzas
  ; url_prefix = Sexp.field_atom_default "url-prefix" ("/" ^ project) stanzas
  ; menu_current = Sexp.field_atom_default "menu-current" project stanzas
  ; packages =
      Sexp.field_atoms "packages" stanzas
      (* [] = assemble every subtree odoc produced (see Build) *)
  ; landing =
      Sexp.field_atom_default "landing" (project ^ "/index.html") stanzas
  ; highlight = Sexp.field_atom "highlight" stanzas
  ; profile = Sexp.field_atom "profile" stanzas
  ; odoc_driver
  ; doc_manual = Sexp.field_atom "doc-manual" stanzas = Some "true"
  ; manual_files = Sexp.field_atom "manual-files" stanzas
  ; siblings = parse_siblings stanzas
  ; nav = parse_nav stanzas
  ; variants
  ; hosted = parse_hosted stanzas
  ; manual_root =
      Sexp.field_atom "manual-root" stanzas = Some "true"
      || Sexp.fields "manual-root" stanzas <> []
  ; mld_dir
  ; mld_package
  ; flat =
      Sexp.field_atom "flat" stanzas = Some "true"
      || Sexp.fields "flat" stanzas <> []
  ; static_copy = parse_static_copy stanzas
  ; blog = parse_blog stanzas
  ; (* Markdown twins + llms.txt are on by default; only (markdown false) disables *)
    markdown = Sexp.field_atom "markdown" stanzas <> Some "false"
  ; (* stylesheet hrefs; [] means "ship the built-in default theme" (see Build) *)
    css = Sexp.field_atoms "css" stanzas
  ; llms = parse_llms stanzas }
