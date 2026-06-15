
# Module `Wodoc.Nav`

Build a project's API module navigation from a curated odoc index.

The manual's own left navigation is no longer generated from a wikicréole menu: it is described declaratively in the project's `doc/wodoc` config (the `(nav …)` stanza) and rendered by [`Build`](./Wodoc-Build.md). This module only renders the API module list, from a curated odoc `.indexdoc`.

```ocaml
val api : 
  ?wrapper:string ->
  ?heading:string ->
  ?skip:string list ->
  base:string ->
  lib:string ->
  string ->
  string
```
`api ~base ~lib indexdoc` renders the API module `<nav>` from a curated odoc index (`{N title}` sections \+ `{!modules: …}` lists). The OCaml port of `gen-nav.py`. A module path `A.B.C` maps to `<base>/<lib>/[<wrapper>/]A/B/C/index.html`. `skip` lists section titles to drop (page titles, `Index`); `heading` is the `<h3>` (default `"Modules"`).
