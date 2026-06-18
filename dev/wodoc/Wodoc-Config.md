
# Module `Wodoc.Config`

```ocaml
type entry = {
  label : string; (* visible text *)
  path : string; (* href: relative to the version root (filled with base), unless it is absolute (/…) or a URL (http(s)://…), which is emitted verbatim *)
  current : string; (* data-wodoc-page id (highlighted on its own pages) *)
}
```
```ocaml
type item = 
  | Link of entry
  | Group of string * item list (* a sub-heading (<h4>) and its nested items, one indent level deeper. Lets a manual nav reproduce a multi-level menu (sections, subsections, page links) — what the old wikicréole menu expressed with ==/===. *)
```
```ocaml
type section = {
  heading : string; (* the <h3> label of this left-nav block *)
  api : bool; (* api-section -> class "api-nav"; else "api-nav manual-nav" *)
  items : item list;
}
```
```ocaml
type blog = {
  dir : string; (* directory of post sources, named YYYY-MM-DD-slug.mld (the date is the publication date; posts sort newest-first on it). Relative to the config file's directory. The posts are plain .mld (author from @author). *)
  out : string; (* output subdirectory under the version root, e.g. "blog": posts deploy as <out>/blog/<slug>.html *)
  heading : string; (* the generated left-nav section <h3> label, e.g. "Blog" *)
  latest : int; (* how many recent posts the {%wodoc:blog-latest%} marker expands to on the landing page *)
}
```
an ultra-simple blog: a directory of dated `.mld` posts that wodoc builds like any other page, auto-listing them in a generated left-nav section and exposing the most recent ones to the landing via the `{%wodoc:blog-latest%}` marker. Generic (no project hardcoding); `None` when the project declares no `(blog …)`.

```ocaml
type cs_side = {
  side : string; (* key, e.g. "server" — body class wodoc-server, switch id *)
  lib : string; (* odoc subtree dir / Nav.api ~lib, e.g. "eliom.server" *)
  indexdoc : string; (* curated index path (relative to the build cwd) *)
  heading : string; (* API-nav heading + switch-button label, e.g. "Server API" *)
  wrapper : string; (* Nav.api ~wrapper / page wrapper module, e.g. "Eliom" *)
  skip : string list; (* section titles to omit (Nav.api ~skip) *)
}
```
one API "side" of a client/server project (eliom/toolkit/start): the `<pkg>.server` / `<pkg>.client` / `<pkg>.ppx` library, whose curated index becomes a section-grouped module nav (via [`Nav.api`](./Wodoc-Nav.md#val-api)). The side also drives a body colour class (`wodoc-<side>`) and a switch button.

```ocaml
type t = {
  project : string; (* package / project id, e.g. "ocsipersist" *)
  title : string; (* sub-project label by the logo, e.g. "Ocsipersist" *)
  pub : string; (* absolute publish base for the version selector, e.g. "/ocsipersist" *)
  menu_current : string; (* project id highlighted in the shared top menu *)
  packages : string list; (* odoc output subtrees to assemble, in order *)
  landing : string; (* index.html redirect target, e.g. "ocsipersist/index.html" *)
  highlight : string option; (* project highlight.js to ship, if any *)
  profile : string option; (* dune build profile (e.g. "release") *)
  odoc_driver : string option; (* when set, build the API with odoc_driver <pkg> --remap (the engine ocaml.org uses) instead of dune build @doc: needed for a client/server package whose <pkg>.server/<pkg>.client libraries share module names and would collide under dune build @doc (eliom, ocsigen-toolkit, ocsigen-start). *)
  doc_manual : bool; (* also build the @doc-manual alias (examples) *)
  manual_files : string option; (* package dir to receive manual/files (examples, images) *)
  siblings : (string * string list) list; (* resolve-refs sibling table *)
  nav : section list;
  client_server : cs_side list; (* when non-empty, the project is client/server: instead of one nav from nav, wodoc builds a per-side API nav from each side's curated index, shows a client/server switch, and colours the body by side. The manual nav is shared, taken from nav's manual ((section …)) blocks. *)
  hosted : (string * (string * Resolve.layout * string)) list; (* cross-project resolve-refs table (resolve-refs --hosted): package -> (deploy dir, layout, wrapper module). Rewrites sibling Ocsigen projects' ocaml.org xrefs to relative links into their wodoc docs. See Resolve.layout for the layout token (multilib/root/subdir). *)
  manual_root : bool; (* deploy the package's pages at the version ROOT instead of under a <package>/ subdirectory: strip the leading <package>/ segment from output paths, the landing and the nav links. Makes a single-package dune build @doc project (ocsigenserver, i18n) match the layout of odoc-driver projects (eliom: manual at the version root, e.g. /ocsigenserver/latest/config.html) so cross-project links resolve. The package's internal relative links are preserved (the same prefix is stripped from every page). *)
  mld_dir : string option; (* direct-mld build (a manual-only / archived project with no dune build @doc): compile every .mld in this dir straight with odoc (preprocess -> compile -> link -> html-generate). The pages are the manual; the landing index.html is a real page (no redirect). *)
  mld_package : string; (* odoc --package for the direct-mld compile (the src subtree) *)
  flat : bool; (* assemble --flat (content straddling odoc's preamble boundary) *)
  static_copy : (string * string) list; (* verbatim copies into the output: (source path, dest under <out>) — e.g. a frozen API snapshot, or a manual image *)
  blog : blog option; (* an optional (blog …) section (see blog) *)
  markdown : bool; (* emit the Markdown twin of every page + the llms.txt/llms-full.txt index (for AI/LLM consumption). On by default; (markdown false) turns it off. *)
}
```
```ocaml
val parse_entry : Sexp.t -> entry
```
```ocaml
val parse_items : Sexp.t list -> item list
```
```ocaml
val parse_section : bool -> Sexp.t -> section
```
```ocaml
val parse_nav_blocks : Sexp.t list -> section list
```
```ocaml
val parse_nav : Sexp.t list -> section list
```
```ocaml
val nav_of_string : string -> section list
```
```ocaml
val parse_siblings : Sexp.t list -> (string * string list) list
```
```ocaml
val parse_client_server : Sexp.t list -> cs_side list
```
```ocaml
val parse_hosted : 
  Sexp.t list ->
  (string * (string * Resolve.layout * string)) list
```
```ocaml
val parse_blog : Sexp.t list -> blog option
```
```ocaml
val parse_static_copy : Sexp.t list -> (string * string) list
```
```ocaml
val of_string : string -> t
```