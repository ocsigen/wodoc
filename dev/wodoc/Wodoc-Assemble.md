
# Module `Wodoc.Assemble`

Assembly layer: wrap odoc's rendered HTML in a project-provided site template.

wodoc stays generic: the project owns all of its chrome (header, menus, drawer, footer, version selector) as a plain HTML *template* with named holes. This module only:

- extracts the meaningful parts from odoc's HTML output ([`Parts.of_odoc_html`](./Wodoc-Assemble-Parts.md#val-of_odoc_html));
- fills the holes of the template ([`fill`](./#val-fill));
- marks the current navigation entry ([`mark_current`](./#val-mark_current)).
A template is HTML containing holes written `{{name}}`. The standard holes filled by [`page`](./#val-page) are `{{base}}`, `{{title}}`, `{{preamble}}`, `{{toc}}` and `{{content}}`. Menu links carry a `data-wodoc-page` attribute; the entry whose value equals the current page id receives the `current` class.

```ocaml
module Parts : sig ... end
```
```ocaml
val fill : template:string -> (string * string) list -> string
```
`fill ~template bindings` replaces every `{{key}}` in `template` with its bound value. Unbound holes are left untouched.

```ocaml
val mark_current : 
  ?attr:string ->
  ?class_:string ->
  current:string ->
  string ->
  string
```
`mark_current ~current html` adds `class_` (default `"current"`) to every start tag whose `attr` (default `"data-wodoc-page"`) equals `current`, merging with an existing `class`. `current = ""` marks nothing.

```ocaml
val page : 
  ?preamble:bool ->
  ?flat:bool ->
  ?strip_anchors:bool ->
  ?base:string ->
  ?menu:string ->
  ?subproject:string ->
  ?menu_current:string ->
  ?leftnav:string ->
  ?mdlink:string ->
  template:string ->
  current:string ->
  string ->
  string
```
`page ~template ~current odoc_html` builds a full page: extract the odoc parts, [`Render.html`](./Wodoc-Render.md#val-html) the content fragment (the template chrome is never rendered), fill the template holes, then [`mark_current`](./#val-mark_current).

- `preamble` (default `true`): fill `{{preamble}}` with the page `<h1>` title block; pass `false` for pages that should not show a title.
- `flat` (default `false`): for full-width pages whose containers span the odoc preamble/content boundary, concatenate the inner preamble and content (dropping odoc's wrappers) into `{{content}}` and leave `{{preamble}}` empty.
- `strip_anchors` (default `true`): drop odoc's heading hover-anchors.
- `base` (default `""`): fills `{{base}}`, the relative path from the page to the doc root (e.g. `"."`, `".."`, `"../.."`), so a version's internal links stay within that version and never mention it.
- `menu` (default `""`): fills `{{menu}}` with the shared site menu fragment (header, top menu, drawer). The fragment may carry its own holes (`{{subproject}}`, `{{base}}`, `{{leftnav}}`); the first two are filled here, `{{leftnav}}` is left for the caller. Lets every page share one menu source.
- `subproject` (default `""`): fills `{{subproject}}` (the sub-project name shown next to the Ocsigen logo); empty on the vitrine.
- `menu_current` (default `""`): like `current` but for the menu's current *project* entry (`data-wodoc-page=<project>`), kept separate from `current` so a project page can highlight both its menu entry and its in-page nav.
- `leftnav` (default `""`): fills every `{{leftnav}}` hole (the drawer's mobile menu and the left column share one source), so the navigation is defined once instead of being `sed`\-expanded into both slots.
- `mdlink` (default `""`): fills `{{mdlink}}` with the page's `<link rel="alternate" type="text/markdown">` element pointing at its Markdown twin (or `""` when there is no twin), so AIs/LLMs can discover the `.md` version of any page.