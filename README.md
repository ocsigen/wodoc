# wodoc

**wodoc** (web + odoc) is an [odoc](https://github.com/ocaml/odoc) driver that
builds complete, styled **websites** from `.mld` and `.mli` sources — not just
API documentation.

It extends odoc with **backward-compatible presentational markers** for arbitrary
CSS classes, containers and layout, and adds a templating layer to assemble a
full site (header, menus, version selector). Any OCaml project can use it.

## How it works

odoc's lightweight markup is intentionally semantic: it has no way to put an
arbitrary class on an element, no block containers, no page templating. wodoc
adds these through a custom raw-markup target, `{%wodoc:DIRECTIVE%}`:

```
{%wodoc:div class=card%}
  {2 Eliom}
  Write client and server as one program.
{%wodoc:end%}

{%wodoc:@ class=server-code%}
{@ocaml[ let () = run () ]}
```

In that example, `div … end` wraps a block in a `<div class="card">`, and the
`@` directive adds attributes to the **next element** — here it puts
`class="server-code"` on the code block. `@` is wodoc's equivalent of
html_of_wiki's `@@…@@`: it is how you attach an arbitrary class (or `id`,
`style`, …) to an element that odoc would otherwise render bare, without
wrapping it in a container. See the [directives](#directives) table below.

Because the target is unknown to stock odoc, **the very same sources render as
plain semantic documentation** with a stock odoc (for example on ocaml.org),
and as the **full themed website** when built with wodoc. There is no fork of
odoc and no separate dialect to learn.

### Pipeline

Nodes are document representations; each arrow is labelled with the command that
performs the transformation. The same sources take two paths:

```
            .mld / .mli  (sources, with {%wodoc:…%} markers)
                 │
     ┌───────────┴────────────────────────┐
     │ wodoc preprocess                    │ odoc compile/link/html-generate
     ▼                                     ▼
 preprocessed .mld                     plain HTML            ──►  ocaml.org
 ({%html:<!--wodoc:…-->%})             (markers dropped)
     │
     │ odoc compile/link/html-generate
     ▼
 odoc HTML  (markers kept as HTML comments)
     │
     │ wodoc render
     ▼
 HTML fragment  (real nested HTML: containers, classes, images)
     │
     │ wodoc assemble                                          [planned]
     ▼
 themed website page                                ──►  ocsigen.org
```

### Why rewrite the markers to HTML comments?

This is a deliberate trick to work around a limitation of odoc (absence of presentational markup). odoc's HTML
backend only keeps raw markup whose target it knows: `{%html:...%}` is emitted
verbatim, **any other target is silently dropped** (`| _ -> []` in odoc's
generator). That drop is exactly what we want on ocaml.org — `{%wodoc:...%}`
vanishes and the docs stay semantic. But it also means that, by the time we get
odoc's HTML, our own markers are *gone*, so the `Render` pass would have nothing
left to transform.

So before running odoc we rewrite `{%wodoc:d%}` to `{%html:<!--wodoc:d-->%}`.
odoc recognises the `html` target and passes the content through unchanged, as an
**HTML comment**. The comment survives odoc's HTML output (so `Render` can find
it), is invisible in the browser (harmless if `Render` never runs), and is a
clean sentinel to turn into real, nested HTML. We cannot use `{%html:<div>%}`
directly in the sources instead: the `html` target is honoured *everywhere*, so a
real `<div>` would also leak into the plain ocaml.org output, defeating the
"one source, two outputs" goal.

Note that this rewrite happens on a temporary copy at build time; the committed
sources always keep the clean `{%wodoc:...%}` form. It also only applies to
`.mld` text — markers inside `.mli` doc-comments are frozen in the `.cmti` and
cannot be post-processed this way (a future model-level driver would lift this
restriction).

## Directives

| Directive | Effect |
|---|---|
| `div class=…` / `a class=… href=…` / `span class=…` … `end` | open/close a container |
| `@ key=val …` | add attributes to the next element (the `@@` equivalent; `class` is merged) |
| `@ S0 \| S1 \| S2 …` | add attributes at successive nesting levels, each section optionally prefixed by a sibling index (see below) |
| `img src=… class=… alt=…` | a self-contained `<img>` |

### Attributes on nested elements (`@ S0 | S1 | S2`)

A single element rarely needs more than `@ class=…`, but some structures have no
outer element to hang a class on — a table being the typical case: odoc emits the
`<table>`, `<tr>` and `<td>` together, with no marker slot before the row or the
cell. The multi-section form solves this, mirroring html_of_wiki's `@@a@b@c@@`.

Sections are separated by `|`. Section `S0` styles the next element, `S1` the
element reached by descending once into its first child, `S2` by descending
again, and so on. An **empty** section descends a level without styling it. So,
before a table:

```
{%wodoc:@ class=pricing | class=headrow | class=firstcell%}
{t
  | Plan | Price |
  ...
}
```

puts `class="pricing"` on the `<table>`, `class="headrow"` on the first `<tr>`,
and `class="firstcell"` on its first `<th>` — exactly html_of_wiki's "class on
the table / on a row / on a cell". Use empty sections to reach a deeper level
without touching the ones above, e.g. `@ | | class=firstcell`.

A section may start with a **1-based index** to select the *N*th sibling at that
level instead of the first (the default). So `@ class=pricing | 2 class=highlight`
styles the table and its **second** row, and `@ | 2 | 3 class=hot` reaches the
**third cell of the second row**. Sibling skipping respects nesting (a table
inside a cell is skipped as a whole). Each `@` marker descends independently, so
stacking several before one table styles several rows:

```
{%wodoc:@ class=pricing%}
{%wodoc:@ | 2 class=highlight%}
{%wodoc:@ | 4 class=total%}
{t … }
```

## Authoring: what survives on ocaml.org

The `{%wodoc:...%}` target is unknown to stock odoc, so it is **dropped** when the
same sources are built with a stock odoc (e.g. on ocaml.org). Choose per
construct:

- **Must be meaningful on ocaml.org → use native odoc** (never a dropped marker):
  links `{{:url}text}`, content images `{image:url}`, text, code, lists, tables,
  headings. These render identically with or without wodoc.
- **`{%wodoc:@ ...%}`** only adds attributes to a *native* element: the element
  (and its content) survives on ocaml.org, only the class is absent there.
- **Drop on ocaml.org → `{%wodoc:div/span/a/...%}`**: purely presentational
  wrappers and chrome (layout containers, whole-block clickable wrappers). The
  native content inside still survives on ocaml.org; only the shell disappears.

In particular, prefer **native links** so they keep working on ocaml.org; reserve
`{%wodoc:a%}` for making a whole block clickable (which native odoc cannot
express), keeping a native link inside when the target should remain reachable.

## Status

Early work in progress. The core (`Preprocess`, `Render`) and a small CLI are in
place. The assembly layer and a `wiki`→`.mld` converter are next.

```
wodoc preprocess <file.mld>   # {%wodoc:..%} -> {%html:<!--wodoc:..-->%}
wodoc render <odoc.html>      # turn the markers in odoc HTML into real HTML
```

## License

MIT. See [LICENSE](LICENSE).
