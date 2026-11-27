# Module `Wodoc.Resolve`

Link cross-package "sibling" references odoc left unresolved.

odoc only resolves references along dependency edges, so a reference to a sibling package built in the same tree (but not a dependency) is rendered as an `xref-unresolved` span or a bare `<code>` and left dead. This rewrites those into relative links within the version's output. The OCaml port of the per-project `resolve-siblings.py` scripts; one implementation, the sibling table given as data.

```ocaml
val html_escape : string -> string
```
HTML-escape the five characters amp, lt, gt, quote and apostrophe (like Python's `html.escape`).

```ocaml
val link_for : (string * string list) list -> string -> string -> string option
```
`link_for siblings base raw` is the relative URL for the qualified name `raw` (possibly carrying a `"val "`/`"type "`/… kind prefix) when it is rooted at a known sibling, else `None`. `siblings` maps a top module to the path segments of its own directory under the version root (e.g. `"Ppx_lwt"` \-\> `["lwt_ppx"; "Lwt_ppx"; "Ppx_lwt"]`); `base` is the relative path from the page to that root.

```ocaml
val strip_kind_marks : string -> string
```
`strip_kind_marks page` removes the `<!--wodoc-ref:KIND-->` sentinels that [`Render`](./Wodoc-Render.md) leaves before references (see [`Preprocess`](./Wodoc-Preprocess.md)). [`html`](./#val-html) and [`deps`](./#val-deps) consume the sentinel of a reference they link, and keep the others for the next pass: strip what is left once both are done.

```ocaml
val html : 
  siblings:(string * string list) list ->
  base:string ->
  string ->
  string
```
`html ~siblings ~base page` rewrites every sibling reference in `page` (both `xref-unresolved` spans and bare `<code>` qualified names), outside `<pre>` blocks, and returns the new HTML. A `<!--wodoc-ref:KIND-->` sentinel right before a reference gives its kind, which odoc does not render for an unresolved one.

```ocaml
type layout = 
  | Multilib (* one library per variant under <dir>.<key>/ *)
  | Root (* single package at the version root *)
  | Subdir (* multi-package project, each opam package under its own <pkg>/ *)
```
How a hosted project's libraries are laid out under `<dir>/latest/`. Below a library, the module path is odoc's in every layout.

```ocaml
val layout_of_string : string -> layout
```
Parse a `hosted` layout token: `"multilib"`/`"true"` \-\> `Multilib`, `"subdir"` \-\> `Subdir`, anything else (`"root"`/`"false"`) \-\> `Root`.

```ocaml
val is_ours : 
  hosted:(string * (string * layout * string)) list ->
  siblings:(string * string list) list ->
  self:string ->
  in_api:bool ->
  pages:string list ->
  string ->
  bool
```
`is_ours ~hosted ~siblings ~self ~in_api ~pages raw` is whether the unresolved reference `raw` (as odoc titles its span) is a defect of *this* documentation rather than one into a dependency the site does not host, whose spans are expected and cannot be repaired locally (`Stdlib`, `Ppxlib`). Ours are:

- a cross-project page reference (leading `'/'`): if its package is missing from `hosted`, the table is what is wrong;
- a lowercase head, when the page holding it is a manual one (`in_api` is false) or when it names one of `pages`, this build's manual pages: a page or section of this project that leads nowhere. A lowercase head on an API page otherwise names a value or type of a signature odoc could not reach, typically what the standard library's functors document (`key`, `elt` in an applied `Map.Make`), which no change here can fix;
- a module reference the tables cover, except into `self`: a project's reference to a module it does not publish is deliberately left as text.
```ocaml
val deps : 
  hosted:(string * (string * layout * string)) list ->
  relroot:string ->
  version:string ->
  side:string ->
  self:string ->
  string ->
  string
```
`deps ~hosted ~relroot ~version ~side ~self page` rewrites cross-PROJECT references to a hosted Ocsigen project into relative links: both resolved ocaml.org dep links and `xref-unresolved` spans. `hosted` maps a package to `(dir, layout, wrapper)`; a `Subdir` entry also matches any package extending its key with a `-`/`_` separator (whole-family match). `relroot` is the path from the page to the shared root holding every project; `version` is the target's version directory (`"latest"`, or `"dev"` so that a development manual documents against development APIs); `side` is `"server"`/`"client"`/`""` (a sided target with no side falls back to its server library); `self` is the package being documented (its own leftover refs are kept as text). The OCaml port of `resolve-deps.py`. As in [`html`](./#val-html), a `<!--wodoc-ref:KIND-->` sentinel gives the kind of the reference it precedes, hence its anchor (`#type-t` rather than `#val-t`).

```ocaml
val requalify : 
  wrapped:(string * string) list ->
  exists:(string -> bool) ->
  string ->
  string
```
`requalify ~wrapped ~exists page` rewrites flat cross-project links to a wrapped library's module (e.g. `.../eliom.server/Eliom_content/…`, emitted by `odoc_driver --remap` for a doc built against a release from before the library was wrapped) into the qualified path the target deploys (`.../eliom.server/Eliom/Content/…`). `wrapped` maps a project deploy-dir to its wrapper module (`("eliom","Eliom")`). The flat→qualified mapping is not uniform (renamed vs kept module names), so each candidate is probed with `exists` (the caller resolves the candidate URL against the page's location and stats the target).

```ocaml
val ocaml_org_versions : string -> (string * string) list
```
`ocaml_org_versions page`: the `(package, version)` pairs of the ocaml.org documentation links in `page` (`https://ocaml.org/p/<pkg>/<version>/doc/…`), the first version seen for each package.

```ocaml
val markdown : 
  hosted:(string * (string * layout * string)) list ->
  versions:(string * string) list ->
  version:string ->
  own:string list ->
  deployed:(string -> string) ->
  base:string ->
  src:string ->
  out:string ->
  string ->
  string
```
`markdown ~hosted ~versions ~version ~own ~deployed ~base ~src ~out page` rewrites the links of the Markdown twin `page` that cross a package boundary. odoc's Markdown backend has no remap: such a link is relative to odoc's output tree, where each package is a directory, and leads nowhere once deployed. `src` is the page's path in that tree (`<pkg>/…`), `out` its deployed path under the version root, and `base` the relative path from it to that root.

A link into one of the `own` packages (those this build documents) is re-aimed at where `deployed` (a path in odoc's tree to its deployed path) puts the target, when it does not reach it already. A link into another package goes, as [`deps`](./#val-deps) does in the HTML, to the deployed page of a `hosted` project, in its `version` directory (here its Markdown twin), else to the package's documentation on ocaml.org, at the version given by `versions` (`"latest"` when absent). Links in fenced code blocks, absolute links and anchors are left alone.
