(* The declarative wodoc project configuration: one [doc/wodoc] file per project
   replaces its build.sh and its menu.wiki. Read by {!Build}. *)

type entry =
  { label : string  (** visible text *)
  ; path : string
    (** href: relative to the version root (filled with base), unless it is
          absolute ([/…]) or a URL ([http(s)://…]), which is emitted verbatim *)
  ; current : string  (** data-wodoc-page id (highlighted on its own pages) *)
  }

type item =
  | Link of entry
  | Group of string * item list
  (** a sub-heading ([<h4>]) and its nested items, one indent level deeper.
          Lets a manual nav reproduce a multi-level menu (sections, subsections,
          page links) — what the old wikicréole menu expressed with [==]/[===]. *)

type section =
  { heading : string  (** the [<h3>] label of this left-nav block *)
  ; api : bool
    (** [api-section] -> class "api-nav"; else "api-nav manual-nav" *)
  ; items : item list }

type blog =
  { dir : string
    (** directory of post sources, named [YYYY-MM-DD-slug.mld] (the date is the
          publication date; posts sort newest-first on it). Relative to the build
          cwd. The posts are plain [.mld] (author given by odoc's [@author]). *)
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

type cs_side =
  { side : string
    (** key, e.g. "server" — body class [wodoc-server], switch id *)
  ; lib : string  (** odoc subtree dir / [Nav.api ~lib], e.g. "eliom.server" *)
  ; indexdoc : string  (** curated index path (relative to the build cwd) *)
  ; heading : string
    (** API-nav heading + switch-button label, e.g. "Server API" *)
  ; wrapper : string
    (** [Nav.api ~wrapper] / page wrapper module, e.g. "Eliom" *)
  ; skip : string list  (** section titles to omit (Nav.api ~skip) *) }
(** one API "side" of a client/server project (eliom/toolkit/start): the
    [<pkg>.server] / [<pkg>.client] / [<pkg>.ppx] library, whose curated index
    becomes a section-grouped module nav (via {!Nav.api}). The side also drives a
    body colour class ([wodoc-<side>]) and a switch button. *)

type t =
  { project : string  (** package / project id, e.g. "ocsipersist" *)
  ; title : string  (** sub-project label by the logo, e.g. "Ocsipersist" *)
  ; pub : string
    (** absolute publish base for the version selector, e.g. "/ocsipersist" *)
  ; menu_current : string  (** project id highlighted in the shared top menu *)
  ; packages : string list  (** odoc output subtrees to assemble, in order *)
  ; landing : string
    (** index.html redirect target, e.g. "ocsipersist/index.html" *)
  ; highlight : string option  (** project highlight.js to ship, if any *)
  ; profile : string option  (** dune build profile (e.g. "release") *)
  ; odoc_driver : string option
    (** when set, build the API with [odoc_driver <pkg> --remap] (the engine
          ocaml.org uses) instead of [dune build @doc]: needed for a client/server
          package whose [<pkg>.server]/[<pkg>.client] libraries share module names
          and would collide under [dune build @doc] (eliom, ocsigen-toolkit,
          ocsigen-start). *)
  ; doc_manual : bool  (** also build the [@doc-manual] alias (examples) *)
  ; manual_files : string option
    (** package dir to receive manual/files (examples, images) *)
  ; siblings : (string * string list) list  (** resolve-refs sibling table *)
  ; nav : section list
  ; client_server : cs_side list
    (** when non-empty, the project is client/server: instead of one nav from
          [nav], wodoc builds a per-side API nav from each side's curated index,
          shows a client/server switch, and colours the body by side. The manual
          nav is shared, taken from [nav]'s manual ([(section …)]) blocks. *)
  ; hosted : (string * (string * bool * string)) list
    (** cross-project resolve-refs table (resolve-refs --hosted): package ->
          (deploy dir, multi-library?, wrapper module). Rewrites sibling Ocsigen
          projects' [ocaml.org] xrefs to relative links into their wodoc docs. *)
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
    (** verbatim copies into the output: (source path, dest under <out>) — e.g.
          a frozen API snapshot, or a manual image *)
  ; blog : blog option  (** an optional [(blog …)] section (see {!type:blog}) *)
  }

let parse_entry = function
  | Sexp.List [Atom label; Atom path; Atom current] -> {label; path; current}
  | Sexp.List [Atom label; Atom path] -> {label; path; current = ""}
  | _ -> raise (Sexp.Error "bad (link <label> <path> [<current>]) entry")

(* a nav section body: a flat list of [(link …)] and nested [(group …)] blocks.
   Anything else is ignored, so comments and stray atoms are harmless. *)
let rec parse_items items =
  List.filter_map
    (function
      | Sexp.List (Atom "link" :: rest) -> Some (Link (parse_entry (List rest)))
      | Sexp.List (Atom "group" :: Atom heading :: rest) ->
          Some (Group (heading, parse_items rest))
      | _ -> None)
    items

let parse_section api = function
  | Sexp.List (Atom heading :: items) ->
      {heading; api; items = parse_items items}
  | _ -> raise (Sexp.Error "bad nav section")

let parse_nav_blocks blocks =
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
  | blocks :: _ -> parse_nav_blocks blocks
  | [] -> []

(* parse a standalone [(nav …)] file (the [--nav <file>] per-version override),
   reusing the same syntax as the [(nav …)] stanza inside a [doc/wodoc] config. *)
let nav_of_string s = parse_nav (Sexp.parse s)

let parse_siblings stanzas =
  List.filter_map
    (function
      | [Sexp.Atom m; Sexp.Atom segs] ->
          Some
            (m, List.filter (fun s -> s <> "") (String.split_on_char '/' segs))
      | _ -> None)
    (Sexp.fields "sibling" stanzas)

(* (client-server (server (lib ..) (indexdoc ..) (heading ..) (wrapper ..) [(skip ..)..])
                   (client ..) [(ppx ..)]) *)
let parse_client_server stanzas =
  match Sexp.fields "client-server" stanzas with
  | block :: _ ->
      List.filter_map
        (function
          | Sexp.List (Atom side :: fields) ->
              Some
                { side
                ; lib = Sexp.field_atom_default "lib" "" fields
                ; indexdoc = Sexp.field_atom_default "indexdoc" "" fields
                ; heading = Sexp.field_atom_default "heading" side fields
                ; wrapper = Sexp.field_atom_default "wrapper" "" fields
                ; skip = Sexp.field_atoms "skip" fields }
          | _ -> None)
        block
  | [] -> []

(* (hosted (eliom eliom true Eliom) (ocsigenserver ocsigenserver false "") ..) *)
let parse_hosted stanzas =
  match Sexp.fields "hosted" stanzas with
  | block :: _ ->
      List.filter_map
        (function
          | Sexp.List (Atom pkg :: Atom dir :: rest) ->
              let multi =
                match rest with Sexp.Atom m :: _ -> m = "true" | _ -> false
              in
              let wrapper =
                match rest with _ :: Sexp.Atom w :: _ -> w | _ -> ""
              in
              Some (pkg, (dir, multi, wrapper))
          | _ -> None)
        block
  | [] -> []

(* (blog (dir <d>) [(out <o>)] [(heading <h>)] [(latest <n>)]) — at most one *)
let parse_blog stanzas =
  match Sexp.fields "blog" stanzas with
  | fields :: _ ->
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
let parse_static_copy stanzas =
  List.filter_map
    (function
      | [Sexp.Atom src; Sexp.Atom dest] -> Some (src, dest)
      | [Sexp.Atom src] -> Some (src, Filename.basename src)
      | _ -> None)
    (Sexp.fields "static-copy" stanzas)

let of_string s =
  let stanzas = Sexp.parse s in
  let project =
    match Sexp.field_atom "project" stanzas with
    | Some p -> p
    | None -> raise (Sexp.Error "missing (project ...)")
  in
  { project
  ; title = Sexp.field_atom_default "title" project stanzas
  ; pub = Sexp.field_atom_default "pub" ("/" ^ project) stanzas
  ; menu_current = Sexp.field_atom_default "menu-current" project stanzas
  ; packages =
      Sexp.field_atoms "packages" stanzas
      (* [] = assemble every subtree odoc produced (see Build) *)
  ; landing =
      Sexp.field_atom_default "landing" (project ^ "/index.html") stanzas
  ; highlight = Sexp.field_atom "highlight" stanzas
  ; profile = Sexp.field_atom "profile" stanzas
  ; odoc_driver = Sexp.field_atom "odoc-driver" stanzas
  ; doc_manual = Sexp.field_atom "doc-manual" stanzas = Some "true"
  ; manual_files = Sexp.field_atom "manual-files" stanzas
  ; siblings = parse_siblings stanzas
  ; nav = parse_nav stanzas
  ; client_server = parse_client_server stanzas
  ; hosted = parse_hosted stanzas
  ; manual_root =
      Sexp.field_atom "manual-root" stanzas = Some "true"
      || Sexp.fields "manual-root" stanzas <> []
  ; mld_dir = Sexp.field_atom "mld-dir" stanzas
  ; mld_package = Sexp.field_atom_default "mld-package" "" stanzas
  ; flat =
      Sexp.field_atom "flat" stanzas = Some "true"
      || Sexp.fields "flat" stanzas <> []
  ; static_copy = parse_static_copy stanzas
  ; blog = parse_blog stanzas }
