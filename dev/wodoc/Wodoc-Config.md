# Module `Wodoc.Config`

```ocaml
type entry = {
  label : string; (* visible text *)
  path : string; (* href: relative to the version root (filled with base), unless it is absolute (/…) or a URL (http(s)://…), which is emitted verbatim *)
  current : string; (* data-wodoc-page id (highlighted on its own pages) *)
}
```
```ocaml
type 'tree item = 
  | Link of entry
  | Group of 'tree group
  | Page_tree of 'tree (* (page-tree [<index>]): the page tree odoc builds from the manual's directories (odoc-pages/<dir>/, ordered by @children_order), below the page <index> (default index.html), as odoc_driver writes it in sidebar.json, without its library and source entries. Expanded before rendering, so the left column follows the same tree as ocaml.org. *)
```
```ocaml
and 'tree group = {
  heading : string;
  index : string option; (* the page the heading links to (a directory of a page tree whose index page is clickable), relative to the version root *)
  items : 'tree item list;
}
```
a sub-heading (`<h4>`) and its nested items, one indent level deeper. Lets a manual nav reproduce a multi-level menu (sections, subsections, page links), as the old wikicréole menu expressed with `==`/`===`.

```ocaml
type expanded = |
```
```ocaml
type 'tree section = {
  heading : string; (* the <h3> label of this left-nav block *)
  api : bool; (* api-section -> class "api-nav"; else "api-nav manual-nav" *)
  items : 'tree item list;
}
```
```ocaml
type llms = {
  llms_title : string option; (* the index's # title; default: the (title …) label, which is short because the site shows it by its logo *)
  llms_summary : string option; (* the index's > summary; default: the first paragraph of the landing page *)
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
type variant = {
  key : string; (* e.g. "server": body class wodoc-server, switch class wodoc-variant-server, notice class wodoc-variant-notice-server *)
  lib : string; (* odoc subtree dir / Nav.api ~lib, e.g. "eliom.server" *)
  indexdoc : string; (* curated index path (relative to the build cwd) *)
  heading : string; (* API-nav heading + switch label, e.g. "Server API" *)
  wrapper : string; (* Nav.api ~wrapper / page wrapper module, e.g. "Eliom" *)
  skip : string list; (* section titles to omit (Nav.api ~skip) *)
  note : string; (* plain text added to the variant notice of its pages, e.g. "This code runs in the browser."; "" for none *)
}
```
one variant of the API of a package whose libraries share module names: the `eliom.server` and `eliom.client` libraries of Eliom, say, or `foo.unix` and `foo.js`. Its curated index becomes a section-grouped module nav (via [`Nav.api`](./Wodoc-Nav.md#val-api)); it also drives a body class (`wodoc-<key>`), a link of the variant switch and a notice at the top of each of its pages.

```ocaml
type t = {
  project : string; (* package / project id, e.g. "ocsipersist" *)
  title : string; (* sub-project label by the logo, e.g. "Ocsipersist" *)
  url_prefix : string; (* absolute URL path the site is published at, e.g. "/ocsipersist"; used by the version selector to switch versions *)
  menu_current : string; (* project id highlighted in the shared top menu *)
  packages : string list; (* odoc output subtrees to assemble, in order *)
  landing : string; (* index.html redirect target, e.g. "ocsipersist/index.html" *)
  highlight : string option; (* project highlight.js to ship, if any *)
  profile : string option; (* dune build profile (e.g. "release") *)
  odoc_driver : string option; (* when set, build the API with odoc_driver <pkg> --remap (the engine ocaml.org uses) instead of dune build @doc: needed for a package whose libraries share module names ((variants …), e.g. eliom.server/eliom.client), which would collide under dune build @doc. *)
  doc_manual : bool; (* also build the @doc-manual alias (examples) *)
  manual_files : string option; (* package dir to receive manual/files (examples, images) *)
  siblings : (string * string list) list; (* resolve-refs sibling table *)
  nav : string section list option; (* the (nav …) stanza; None when the config has none: the left column then shows the manual tree odoc builds, as (nav (section <title> (page-tree))) would, if odoc_driver wrote its sidebar.json *)
  variants : variant list; (* when non-empty, the API comes in variants: instead of one nav from nav, wodoc builds a per-variant API nav from each variant's curated index, shows a variant switch, and colours the body by variant. The manual nav is shared, taken from nav's manual ((section …)) blocks. *)
  hosted : (string * (string * Resolve.layout * string)) list; (* cross-project resolve-refs table (resolve-refs --hosted): package -> (deploy dir, layout, wrapper module). Rewrites sibling Ocsigen projects' ocaml.org xrefs to relative links into their wodoc docs. See Resolve.layout for the layout token (multilib/root/subdir). *)
  manual_root : bool; (* deploy the package's pages at the version ROOT instead of under a <package>/ subdirectory: strip the leading <package>/ segment from output paths, the landing and the nav links. Makes a single-package dune build @doc project (ocsigenserver, i18n) match the layout of odoc-driver projects (eliom: manual at the version root, e.g. /ocsigenserver/latest/config.html) so cross-project links resolve. The package's internal relative links are preserved (the same prefix is stripped from every page). *)
  mld_dir : string option; (* direct-mld build (a manual-only / archived project with no dune build @doc): compile every .mld in this dir straight with odoc (preprocess -> compile -> link -> html-generate). The pages are the manual; the landing index.html is a real page (no redirect). *)
  mld_package : string; (* odoc parent id of the pages in the direct-mld build, and the root of the ids of the assets under <mld-dir>/files (the src subtree). The project when empty. *)
  flat : bool; (* assemble --flat (content straddling odoc's preamble boundary) *)
  static_copy : (string * string) list; (* verbatim copies into the output: (source path, dest under <out>), e.g. a frozen API snapshot, or a manual image *)
  blog : blog option; (* an optional (blog …) section (see blog) *)
  markdown : bool; (* emit the Markdown twin of every page + the llms.txt/llms-full.txt index (for AI/LLM consumption). On by default; (markdown false) turns it off. *)
  css : string list; (* stylesheet hrefs for the page <head>. Each is emitted verbatim when absolute (/…) or a URL, else made per-page relative ({{base}}/…) and, when it names a file next to the config, copied into the output, so a project can ship a self-contained theme that works at any deploy path. [] (the default) ships wodoc's built-in default theme as wodoc.css. *)
  llms : llms; (* the (llms …) stanza (see llms) *)
}
```
```ocaml
val retired_stanzas : (string * string) list
```
```ocaml
val check_keys : 
  ?retired:(string * string) list ->
  where:string ->
  string list ->
  Sexp.t list ->
  unit
```
```ocaml
val parse_entry : Sexp.t -> entry
```
```ocaml
val parse_items : Sexp.t list -> string item list
```
```ocaml
val parse_section : bool -> Sexp.t -> string section
```
```ocaml
val parse_nav_blocks : Sexp.t list -> string section list
```
```ocaml
val parse_nav : Sexp.t list -> string section list option
```
```ocaml
val nav_of_string : string -> string section list option
```
```ocaml
val parse_siblings : Sexp.t list -> (string * string list) list
```
```ocaml
val reserved_variant_keys : string list
```
```ocaml
val is_variant_key : string -> bool
```
```ocaml
val parse_variants : Sexp.t list -> variant list
```
```ocaml
val parse_hosted : 
  Sexp.t list ->
  (string * (string * Resolve.layout * string)) list
```
```ocaml
val parse_llms : Sexp.t list -> llms
```
```ocaml
val parse_blog : Sexp.t list -> blog option
```
```ocaml
val check_static_dest : string -> string
```
```ocaml
val parse_static_copy : Sexp.t list -> (string * string) list
```
```ocaml
val stanza_names : string list
```
```ocaml
val of_string : string -> t
```
