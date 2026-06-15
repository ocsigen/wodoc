
# Module `Assemble.Parts`

```ocaml
type t = {
  title : string; (* plain text of the page's <h1> *)
  preamble : string; (* the odoc-preamble header, verbatim *)
  toc : string; (* the odoc-tocs block, verbatim (may be empty) *)
  content : string; (* the odoc-content block, verbatim *)
}
```
```ocaml
val of_odoc_html : string -> t
```
Extract the parts from a full odoc-generated HTML page.
