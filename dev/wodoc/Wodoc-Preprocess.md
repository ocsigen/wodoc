
# Module `Wodoc.Preprocess`

Pre-processing of odoc source files.

wodoc sources use a clean custom raw-markup target, `{%wodoc:DIRECTIVE%}`, for presentational extensions (containers, classes, images). Stock odoc drops unknown raw-markup targets, so the very same source renders as plain semantic documentation (e.g. on ocaml.org).

To render the rich website we instead need odoc to emit the directives so that [`Render`](./Wodoc-Render.md) can turn them into real HTML. This module rewrites `{%wodoc:DIRECTIVE%}` into `{%html:<!--wodoc:DIRECTIVE-->%}`, which stock odoc preserves (as an HTML comment) in its HTML output.

This only applies to source text odoc reads directly (i.e. `.mld` files). Markers embedded in `.mli` doc-comments are compiled into `.cmti` before odoc sees them and cannot be pre-processed this way.

```ocaml
val string : string -> string
```
`string s` rewrites every `{%wodoc:d%}` occurrence in `s` into `{%html:<!--wodoc:d-->%}`. Other content is left untouched.
