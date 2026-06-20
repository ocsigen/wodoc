
# Directives

Every wodoc extension is written as a raw-markup target, `{%wodoc:DIRECTIVE%}`. The directives below are all wodoc understands; everything else in your sources is plain odoc.

| Directive | Effect |
| --- | --- |
| `div` / `span` / `a href=…` / `section` / `header` / `nav` / `article` / `aside` / `footer` (each takes `class=…`) … `end` | open / close a container |
| `@ key=val …` | add attributes to the **next element** (the `@@` equivalent; `class` is merged) |
| `@ S0 \| S1 \| S2 …` | add attributes at successive nesting levels (see below) |
| `img src=… class=… alt=…` | a self-contained `<img>` |
| `blog-latest` | expand into the blog's "latest posts" list (see [Adding a blog](./blog.md)) |
**Several classes**, HTML-style, are written space-separated inside quotes — `{%wodoc:@ class="card big shadow"%}`. The quotes are required: without them the space ends the value, so `class=card big shadow` would keep only `card`. The classes are merged with any class odoc already put on the element (e.g. `{%wodoc:@ class="pricing wide"%}` on a table yields `class="odoc-table pricing wide"`).


## Containers

`{%wodoc:div class=card%}` … `{%wodoc:end%}` wraps everything between the two markers in a `<div class="card">`. The same form works for `span` (inline), `a` (a link around a whole block, which native odoc cannot express) and the HTML5 semantic blocks `section`, `header`, `nav`, `article`, `aside` and `footer` (e.g. `{%wodoc:section class=hero%}` … `{%wodoc:end%}` emits a `<section class="hero">`):

```text
{%wodoc:a class=main-page-project-link href=../eliom/%}
{%wodoc:div class=main-page-project%}
  {2 Eliom}
  Write client and server as one program.
{%wodoc:end%}{%wodoc:end%}
```
wodoc re-nests these into correctly balanced HTML, hoisting them out of the `<p>` wrappers odoc forces around inline raw markup (the limitation that makes `{%html:<div>%}` alone unusable for blocks).


## The `@` directive

`{%wodoc:@ key=val …%}` adds attributes to the **next element** without wrapping it in a container — it is wodoc's equivalent of html\_of\_wiki's `@@…@@`. Put it on its own line just before the element. Typical use: tag a code block so the theme can colour it.

```text
{%wodoc:@ class=server-code%}
{@ocaml[ let () = run () 
```

## Attributes on nested elements (`@ S0 | S1 | S2`)

A single element rarely needs more than `@ class=…`, but some structures have no outer element to hang a class on — a table being the typical case: odoc emits the `<table>`, `<tr>` and `<td>` together, with no marker slot before the row or the cell. The multi-section form solves this, mirroring html\_of\_wiki's `@@a@b@c@@`.

Sections are separated by `|`. Section `S0` styles the next element, `S1` the element reached by descending once into its first child, `S2` by descending again, and so on. An **empty** section descends a level without styling it. So, before a table:

```text
{%wodoc:@ class=pricing | class=headrow | class=firstcell%}
{t
  | Plan | Price |
  ...
}
```
puts `class="pricing"` on the `<table>`, `class="headrow"` on the first `<tr>`, and `class="firstcell"` on its first `<th>` — exactly html\_of\_wiki's "class on the table / on a row / on a cell". Use empty sections to reach a deeper level without touching the ones above, e.g. `@ | | class=firstcell`.

A section may start with a **1-based index** to select the *N*th sibling at that level instead of the first (the default). So `@ class=pricing | 2 class=highlight` styles the table and its **second** row, and `@ | 2 | 3 class=hot` reaches the **third cell of the second row**. Sibling skipping respects nesting (a table inside a cell is skipped as a whole). Each `@` marker descends independently, so stacking several before one table styles several rows:

```text
{%wodoc:@ class=pricing%}
{%wodoc:@ | 2 class=highlight%}
{%wodoc:@ | 4 class=total%}
{t … }
```

## Images

`{%wodoc:img src=… class=… alt=…%}` emits a self-contained `<img>`. Use it only for **chrome** (logos, decorative images that need not appear on ocaml.org). For **content** images that must survive on ocaml.org, use native odoc `{image:url}` and, if you need a class, wrap it with `{%wodoc:@ …%}` — see [Authoring](./authoring.md).
