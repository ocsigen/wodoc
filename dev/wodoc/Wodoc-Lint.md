# Module `Wodoc.Lint`

Diagnostics on the pages a build has just produced: markup that was meant to become a link or an image and did not.

Both shapes below have shipped to ocsigen.org unnoticed, because a dead reference degrades into plain text rather than into a build failure. wodoc reports them on every build and, with `wodoc build --strict-refs`, fails.

```ocaml
val unresolved_refs : 
  ours:(string -> bool) ->
  string ->
  string list * string list
```
`unresolved_refs ~ours page` lists the references odoc could not resolve and no rewriting pass could repair, as they read in the page: the reference target when the span carries one, else its visible text. The first list holds the ones `ours` accepts, the dead references of this documentation: a missing entry in the project's tables, a name that no longer exists, an unresolved page of the project itself. The second holds references into dependencies the site does not host (`Stdlib`, `Ppxlib`), which no local change can repair; see [`Wodoc.Resolve.is_ours`](./Wodoc-Resolve.md#val-is_ours).

```ocaml
val wiki_images : string -> string list
```
`wiki_images page` lists leftover wikicréole images (`{{file.png|alt}}`). odoc has no image syntax, so a conversion that missed one leaves it as literal text; only `{%wodoc:img …%}` renders.

```ocaml
val count : (string * string list) list -> (string * string) -> unit
```
`count diagnostics (singular, plural)` prints the one-line total only, for what is worth knowing but not acting on.

```ocaml
exception Dead_markup of string
```
Raised by [`report`](./#val-report) in strict mode; the payload is the summary line.

```ocaml
val report : 
  strict:bool ->
  (string * string list) list ->
  (string * string) ->
  unit
```
`report ~strict diagnostics (singular, plural)` prints one line per page holding such a diagnostic, then a count. Raises [`Dead_markup`](./#exception-Dead_markup) when `strict` and there is anything to report.
