
# Module `Wodoc.Lint`

Diagnostics on the pages a build has just produced: markup that was meant to become a link or an image and did not.

Both shapes below have shipped to ocsigen.org unnoticed, because a dead reference degrades into plain text rather than into a build failure. wodoc reports them on every build and, with `wodoc build --strict-refs`, fails.

```ocaml
val unresolved_refs : string -> string list
```
`unresolved_refs page` lists the references odoc could not resolve and no rewriting pass could repair, as they read in the page: the `(hosted …)` target when the span carries one, else its visible text. Each is a dead reference — a missing entry in the project's tables, or a name that no longer exists.

```ocaml
val wiki_images : string -> string list
```
`wiki_images page` lists leftover wikicréole images (`{{file.png|alt}}`). odoc has no image syntax, so a conversion that missed one leaves it as literal text; only `{%wodoc:img …%}` renders.

```ocaml
exception Dead_markup of string
```
Raised by [`report`](./#val-report) in strict mode; the payload is the summary line.

```ocaml
val report : strict:bool -> (string * string list) list -> string -> unit
```
`report ~strict diagnostics kind` prints one line per page holding a `kind` ("unresolved reference", …) diagnostic, then a count. Raises [`Dead_markup`](./#exception-Dead_markup) when `strict` and there is anything to report.
