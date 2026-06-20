
# API reference

wodoc is both a command-line tool and an OCaml library. The library exposes one module per pass of the [pipeline](./overview.md); the `wodoc` command-line subcommands ([Commands](./commands.md)) are thin wrappers over them.


## Modules

[`Wodoc.Preprocess`](./Wodoc-Preprocess.md) Pre-processing of odoc source files.
[`Wodoc.Render`](./Wodoc-Render.md) wodoc rendering pass over odoc's HTML output.
[`Wodoc.Assemble`](./Wodoc-Assemble.md) Assembly layer: wrap odoc's rendered HTML in a project-provided site template.
[`Wodoc.Nav`](./Wodoc-Nav.md) Build a project's API module navigation from a curated odoc index.
[`Wodoc.Resolve`](./Wodoc-Resolve.md) Link cross-package "sibling" references odoc left unresolved.
[`Wodoc.Convert`](./Wodoc-Convert.md) Best-effort converter from extended wikicréole to odoc .mld with wodoc markers.
[`Wodoc.Config`](./Wodoc-Config.md) 
[`Wodoc.Build`](./Wodoc-Build.md) 
[`Wodoc.Blog`](./Wodoc-Blog.md) 
[`Wodoc.Llms`](./Wodoc-Llms.md) Generate the LLM-friendly index files for a built project doc, from the Markdown twin tree that Wodoc.Build produces in the output directory.
[`Wodoc.Theme`](./Wodoc-Theme.md) Built-in default assets shipped by wodoc build, so it produces a styled, self-contained site with no theme setup. Each is overridable: the stylesheet via the (css …) config stanza, the top menu via --menu.

## Where to start

- [`Wodoc.Preprocess`](./Wodoc-Preprocess.md) — rewrite `{%wodoc:…%}` markers to HTML-comment sentinels before odoc runs.
- [`Wodoc.Render`](./Wodoc-Render.md) — turn those sentinels in odoc's HTML into real nested HTML.
- [`Wodoc.Assemble`](./Wodoc-Assemble.md) — wrap the rendered HTML in a project's site template.
- [`Wodoc.Nav`](./Wodoc-Nav.md) — render a client/server project's API module list from a curated odoc index (the manual's own navigation is declared in the [`doc/wodoc` config](./config.md), not here).
- [`Wodoc.Resolve`](./Wodoc-Resolve.md) — link cross-package "sibling" references odoc left dead.
- [`Wodoc.Convert`](./Wodoc-Convert.md) — the wikicréole → `.mld` migration aid.
- [`Wodoc.Config`](./Wodoc-Config.md) — parse the declarative [`doc/wodoc`](./config.md) file.
- [`Wodoc.Build`](./Wodoc-Build.md) — the turn-key `wodoc build`: assemble a whole site from it.
- [`Wodoc.Blog`](./Wodoc-Blog.md) — the ultra-simple blog: dated `.mld` posts, a generated nav section and a "latest posts" landing fragment.
- [`Wodoc.Llms`](./Wodoc-Llms.md) — generate the `llms.txt` / `llms-full.txt` index from the Markdown twin tree (the LLM-friendly view of a built site).
- [`Wodoc.Theme`](./Wodoc-Theme.md) — the built-in default assets (theme stylesheet, top bar) shipped when a project configures none.