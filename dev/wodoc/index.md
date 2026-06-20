
# Wodoc

*wodoc* (web \+ odoc) is an [odoc](https://github.com/ocaml/odoc) driver that builds complete, styled **websites** from `.mld` and `.mli` sources — not just API documentation.

It extends odoc with **backward-compatible presentational markers** for arbitrary CSS classes, containers and layout, and adds a templating layer to assemble a full site (header, menus, version selector). Any OCaml project can use it — this very website is built by wodoc from its own sources.

Because wodoc's markers use a custom raw-markup target that stock odoc ignores, **the same sources render as plain semantic documentation** with a stock odoc (for example on [ocaml.org](https://ocaml.org)) and as the **full themed website** when built with wodoc. There is no fork of odoc and no separate dialect to learn.

It can even host an **ultra-simple blog** on your site — dated `.mld` posts, auto-listed in the navigation, with a "latest posts" widget and an Atom feed for syndication. See [Adding a blog](./blog.md).


## Manual

- [How it works](./overview.md) — the pipeline and the one-source/two-outputs trick
- [Building a complete site](./building-a-site.md) — home page, pages, navigation, theme, multiple projects, deployment
- [Directives](./directives.md) — the `{%wodoc:…%}` reference (classes, containers, tables)
- [Authoring](./authoring.md) — what survives on ocaml.org, what is wodoc-only
- [Configuration](./config.md) — the `doc/wodoc` file: navigation, layout, versions.json
- [Commands](./commands.md) — `build` (turn-key), plus `preprocess`, `render`, `assemble`, `nav`, `resolve-refs`, `convert`
- [Adding a blog](./blog.md) — dated `.mld` posts, the navigation list, the feed

## API reference

wodoc is also an OCaml library: the same passes the `wodoc` command-line tool chains are exposed as modules. See the [API overview](./api.md), or jump to [`Wodoc.Preprocess`](./Wodoc-Preprocess.md), [`Wodoc.Render`](./Wodoc-Render.md), [`Wodoc.Assemble`](./Wodoc-Assemble.md), [`Wodoc.Nav`](./Wodoc-Nav.md), [`Wodoc.Resolve`](./Wodoc-Resolve.md) and [`Wodoc.Convert`](./Wodoc-Convert.md).


## About

wodoc is developed in the [ocsigen/wodoc](https://github.com/ocsigen/wodoc) repository and distributed under the MIT license.
