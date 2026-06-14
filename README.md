# wodoc

**wodoc** (web + odoc) is an [odoc](https://github.com/ocaml/odoc) driver that
builds complete, styled **websites** from `.mld` and `.mli` sources — not just
API documentation.

It extends odoc with **backward-compatible presentational markers** for arbitrary
CSS classes, containers and layout, and adds a templating layer to assemble a
full site (header, menus, version selector). Any OCaml project can use it.

## Installation

wodoc is not on the opam repository yet — pin it from git:

```
opam pin add wodoc git+https://github.com/ocsigen/wodoc.git
```

(or `opam pin add wodoc .` from a clone). This also pins the `odoc` family
(`odoc`, `odoc-driver`, …) to the small fork wodoc needs, via the `pin-depends`
in [`wodoc.opam`](wodoc.opam) — no manual setup. It needs OCaml ≥ 5.1 (pulled in
by `odoc-driver`). At run time it shells out to `odoc`/`odoc_driver` and to
`curl` (for `--menu <URL>`).

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
     │ wodoc assemble  (menu, left nav, version selector)
     ▼
 themed website page                                ──►  ocsigen.org
```

`wodoc build` drives this whole pipeline from a declarative `doc/wodoc` config,
for every page of a project, in one command.

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

**Several classes**, HTML-style, are written space-separated inside quotes —
`{%wodoc:@ class="card big shadow"%}`. The quotes are required: without them the
space ends the value, so `class=card big shadow` would keep only `card`. The
classes are merged with any class odoc already put on the element (e.g.
`{%wodoc:@ class="pricing wide"%}` on a table yields
`class="odoc-table pricing wide"`).

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

## Commands

The turn-key command is **`wodoc build`**: from one declarative config it builds
a project's whole documentation site (it runs `dune build @doc` and assembles
every page). The lower-level commands it chains are also available individually.

```
wodoc build --config <doc/wodoc> --out <dir> --menu <menu.html|URL> [--label <v>]
            [--src <odoc _html>] [--latest] [--local]
    turn-key: assemble a whole odoc tree into the themed site from a per-project
    config (project, packages, nav, siblings, …). Replaces a hand-written build
    script, menu.wiki and template/nav HTML. --menu takes a file or an http(s)
    URL; --local also fetches the shared /css//img/ assets for offline preview;
    a default syntax-highlight starter (eliom/lwt/js_of_ocaml ppx) is shipped
    unless (highlight ...) overrides it.

wodoc preprocess <file.mld>
    rewrite {%wodoc:..%} markers into {%html:<!--wodoc:..-->%} so stock odoc
    keeps them as HTML comments

wodoc render [--strip-anchors] <odoc.html>
    turn the markers in odoc's HTML into real, nested HTML

wodoc assemble --template <tmpl.html> [--current <id>] [--base <b>] [--menu <f>]
               [--subproject <s>] [--menu-current <id>] [--leftnav <f>]
               [--no-preamble] [--flat] [--keep-anchors]
               [--blog-config <c>] [--blog-base <b>] <odoc.html>
    wrap rendered odoc HTML in a site template (fills {{title}}/{{preamble}}/
    {{toc}}/{{content}}/{{menu}}/{{leftnav}} and marks the current entry;
    --blog-config expands a {%wodoc:blog-latest%} marker with that blog's
    latest-posts fragment)

wodoc nav  --api <indexdoc> --base <b> --lib <l> [--wrapper <W>] [--skip-title <t>]..
    render an API module navigation fragment from a curated odoc index (used by
    `wodoc build` for client/server projects); the manual's navigation is
    declared in the `doc/wodoc` config's `(nav ...)` stanza, not here

wodoc resolve-refs --base <b> --sibling <Mod=seg/..> [..] <file>..
                   | --hosted <pkg=dir:multi:wrapper> --relroot <r> --side <s> [..]
    link references odoc left dead, across packages (--sibling) or across hosted
    projects (--hosted); rewrites files in place

wodoc convert <file.wiki>
    best-effort wikicréole -> .mld converter to migrate an existing manual
    (headings, lists, links, code blocks, {%wodoc:%} for classes/containers,
    odoc references from <<a_api>>/<<a_manual>>); the output is meant to be
    reviewed by hand

wodoc blog-nav  --config <doc/wodoc> [--base <b>]
    the blog's left-nav block (one entry per post, newest first), for the
    low-level assemble --leftnav path
wodoc blog-feed --config <doc/wodoc> --base-url <origin> [--blog-path <p>]
                [--feed-path /feed.xml] [--title <t>] [--author <a>]
    an Atom feed of the blog posts, for syndication (e.g. OCaml Planet)
```

A turn-key build is a single `wodoc build` per version, configured by a
`doc/wodoc` file; under the hood it chains `preprocess | odoc | render |
assemble` per page (plus `nav`/`resolve-refs` for the navigation and
cross-package links), using `convert` once up front to bring a legacy wiki manual
over to `.mld`.

## Blog

wodoc can carry an **ultra-simple blog** with no extra tooling: a post is a plain
`.mld` named `YYYY-MM-DD-slug.mld` (the date prefix is the publication date, so
posts sort newest-first with no metadata file; the author is odoc's `@author`,
the title the page heading, the excerpt the first paragraph). Declare it with a
`(blog (dir …) (out …) (heading …) (latest …))` stanza in `doc/wodoc`:
`wodoc build` then builds each post like any page, auto-lists them in a generated
left-nav section, and expands a `{%wodoc:blog-latest%}` marker on the landing
into a styled "latest posts" list (`.wodoc-blog-*` classes, styled by your
theme). A site that builds its home through the low-level `assemble` path can
carry the same listing with `--blog-config`/`--blog-base`, its full left-nav
block with `wodoc blog-nav`, and an Atom feed (for OCaml Planet and the like)
with `wodoc blog-feed`. See the [Configuration](manual/config.mld) manual.

## Status

Early work in progress.

## License

MIT. See [LICENSE](LICENSE).
