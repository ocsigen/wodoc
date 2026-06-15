
# Module `Wodoc.Render`

wodoc rendering pass over odoc's HTML output.

odoc emits the `{%html:<!--wodoc:DIRECTIVE-->%}` markers produced by [`Preprocess`](./Wodoc-Preprocess.md) as HTML comments. This pass turns those comments into real, correctly nested HTML and removes the `<p>` wrappers odoc forces around inline raw-markup.

Supported directives (the content after `wodoc:`):

- `div class=...` / `a class=... href=...` / `span class=...` open a container, paired with `end` which closes the most recent one;
- `\@ S0 | S1 | S2` adds attributes at successive nesting levels: section `Si` is applied to the element reached by descending `i` times into the first child element, starting at the next element. This is the `\@\@` equivalent and mirrors html\_of\_wiki's `\@\@a\@b\@c\@\@` (e.g. table / row / cell). A `class` is merged with any existing one; an empty section styles nothing but still descends. A single section (`\@ class=...`) targets the next element. The marker must stand alone (a blank line before the element it applies to), so it targets the following element rather than being absorbed into a paragraph;
- `img src=... class=... alt=...` emits a self-contained `<img>`.
The directive set is intentionally small and generic; project-specific widgets (menus, switches…) belong to the assembly layer, not here.

```ocaml
val html : ?strip_anchors:bool -> string -> string
```
`html s` processes the wodoc markers in odoc's HTML `s` and returns the transformed HTML. Markers are consumed; on malformed input the offending marker is left as an HTML comment rather than raising.

`strip_anchors` (default `false`) removes the empty hover-link anchors odoc inserts inside headings — useful for website pages (and required when a heading sits inside a clickable card link, to avoid a nested `<a>`).
