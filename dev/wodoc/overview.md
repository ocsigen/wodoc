
# How wodoc works

odoc's lightweight markup is intentionally semantic: it has no way to put an arbitrary class on an element, no block containers, no page templating. wodoc adds these through a custom raw-markup target, `{%wodoc:DIRECTIVE%}`:

```text
{%wodoc:div class=card%}
  {2 Eliom}
  Write client and server as one program.
{%wodoc:end%}

{%wodoc:@ class=server-code%}
{@ocaml[ let () = run () 
```
In that example, `div … end` wraps a block in a `<div class="card">`, and the `@` directive adds attributes to the **next element** — here it puts `class="server-code"` on the code block. See the [directives reference](./directives.md) for the full list.

Because the target is unknown to stock odoc, **the very same sources render as plain semantic documentation** with a stock odoc (for example on ocaml.org), and as the **full themed website** when built with wodoc. There is no fork of odoc and no separate dialect to learn.


## Pipeline

The same sources take two paths. Each arrow is the command that performs the transformation.

```text
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
     │ wodoc assemble
     ▼
 themed website page                                ──►  ocsigen.org
```
The turn-key [`wodoc build`](./commands.md) command drives this whole pipeline from one declarative `doc/wodoc` config: it runs `dune build @doc` and chains `preprocess | odoc | render | assemble` for every page (adding the navigation and cross-package link resolution), using [`convert`](./commands.md) once up front to bring a legacy wikicréole manual over to `.mld`.


## Why rewrite the markers to HTML comments?

This is a deliberate trick to work around a limitation of odoc (the absence of presentational markup). odoc's HTML backend only keeps raw markup whose target it knows: `{%html:...%}` is emitted verbatim, **any other target is silently dropped** (`| _ -> []` in odoc's generator). That drop is exactly what we want on ocaml.org — `{%wodoc:...%}` vanishes and the docs stay semantic. But it also means that, by the time we get odoc's HTML, our own markers are *gone*, so the [`Wodoc.Render`](./Wodoc-Render.md) pass would have nothing left to transform.

So before running odoc we rewrite `{%wodoc:d%}` to `{%html:<!--wodoc:d-->%}`. odoc recognises the `html` target and passes the content through unchanged, as an **HTML comment**. The comment survives odoc's HTML output (so `render` can find it), is invisible in the browser (harmless if `render` never runs), and is a clean sentinel to turn into real, nested HTML. We cannot use `{%html:<div>%}` directly in the sources instead: the `html` target is honoured *everywhere*, so a real `<div>` would also leak into the plain ocaml.org output, defeating the "one source, two outputs" goal.

Note that this rewrite happens on a temporary copy at build time; the committed sources always keep the clean `{%wodoc:...%}` form. It also only applies to `.mld` text — markers inside `.mli` doc-comments are frozen in the `.cmti` and cannot be post-processed this way (a future model-level driver would lift this restriction).
