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

Because the target is unknown to stock odoc, **the very same sources render as
plain semantic documentation** with a stock odoc (for example on ocaml.org),
and as the **full themed website** when built with wodoc. There is no fork of
odoc and no separate dialect to learn.

### Pipeline

```
 source .mld / .mli
   │  Preprocess :  {%wodoc:d%}  ->  {%html:<!--wodoc:d-->%}   (.mld only)
   ▼
 stock odoc  (compile / link / html-generate)
   │  the markers survive as HTML comments
   ▼
 Render :  comments -> real, correctly nested HTML
   │        containers, classes (the @@ equivalent), images
   ▼
 Assemble :  wrap with the site chrome (header / menu / version)   [planned]
   ▼
 themed website                              +   ocaml.org (plain odoc)
```

## Directives

| Directive | Effect |
|---|---|
| `div class=…` / `a class=… href=…` / `span class=…` … `end` | open/close a container |
| `@ key=val …` | add attributes to the next element (the `@@` equivalent; `class` is merged) |
| `img src=… class=… alt=…` | a self-contained `<img>` |

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

LGPL-2.1 with the OCaml linking exception.
