
# Module `Wodoc`

```ocaml
module Assemble : sig ... end
```
Assembly layer: wrap odoc's rendered HTML in a project-provided site template.

```ocaml
module Blog : sig ... end
```
```ocaml
module Build : sig ... end
```
```ocaml
module Config : sig ... end
```
```ocaml
module Convert : sig ... end
```
Best-effort converter from extended wikicréole to odoc `.mld` with wodoc markers.

```ocaml
module Llms : sig ... end
```
Generate the LLM-friendly index files for a built project doc, from the Markdown twin tree that [`Build`](./Wodoc-Build.md) produces in the output directory.

```ocaml
module Nav : sig ... end
```
Build a project's API module navigation from a curated odoc index.

```ocaml
module Preprocess : sig ... end
```
Pre-processing of odoc source files.

```ocaml
module Render : sig ... end
```
wodoc rendering pass over odoc's HTML output.

```ocaml
module Resolve : sig ... end
```
Link cross-package "sibling" references odoc left unresolved.

```ocaml
module Sexp : sig ... end
```