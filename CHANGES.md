# Changes

## 1.0

Simplified setup — `wodoc build` now produces a styled, self-contained site with
no theme configuration:

- A built-in default theme is shipped as `wodoc.css` and a default top bar is
  generated, both linked by per-version relative paths (the site works at any
  deploy path). `--menu` is now optional (it overrides the default bar), and the
  stylesheet is chosen by `(css …)` — a relative href is copied into the build, an
  absolute/URL href is used verbatim; omitting it ships the built-in theme.
- The highlight starter is always linked relatively (no shared absolute path).

## 0.1

First release: an odoc driver that builds complete, styled websites from `.mld`
and `.mli` sources. It provides:

- `Preprocess`: rewrite `{%wodoc:..%}` markers into `{%html:<!--wodoc:..-->%}`
  so stock odoc preserves them as HTML comments.
- `Render`: turn the markers in odoc's HTML output into real, correctly nested
  HTML — containers (`div`/`a`/`span`, the semantic blocks
  `section`/`header`/`nav`/`article`/`aside`/`footer`, and `end`), multi-level
  attribute injection
  (`@ S0 | S1 | S2`, html_of_wiki's `@@` equivalent: successive nesting levels — e.g.
  table / row / cell — mirroring html_of_wiki's `@@a@b@c@@`; each section may
  start with a 1-based sibling index to reach the Nth row/cell rather than the
  first, sibling skipping respecting nesting), and self-contained
  images (`img`). Hoists structural tags out of odoc's forced `<p>` wrappers.
  A standalone `@` marker targets the following element (paragraph, table,
  heading…); empty `<p>` left behind by a marker are dropped. Optional
  `strip_anchors` removes odoc's empty hover-link anchors from headings (useful
  for website pages and required when a heading sits inside a clickable link).
  Attribute values may be quoted (`class="a b c"`) to hold several classes;
  balanced inline elements (e.g. `<a>text</a>`) are left untouched, only tags
  that span paragraphs are hoisted.
- `Convert` / `wodoc convert`: best-effort wikicréole → `.mld` converter (a
  migration aid): headings, bold/italic/monospace, links, lists, code blocks,
  `<<div/span/header>>` wrappers, `<<|...>>` comments, `@@class@@` attributes,
  images and `\\` line breaks. `{{{...}}}` becomes verbatim, `<<code lang|...>>`
  becomes a highlighted code block (a `class=` on it, e.g. Eliom's
  server/client/shared, is kept as a wodoc attribute marker for side colouring),
  and indented headings/lists are recognised.
  `<<a_api [text=..]|module M / val M.f>>` becomes an odoc reference
  (`{!M}` / `{{!M}text}`); with a `subproject`/`project` (or the `--api-side`
  default for a sided manual) it becomes a relative link into the themed API
  (`../<pkg>.<side>/<path>/index.html`, or another project's `/wodoc/<P>/…`),
  with the right page and odoc anchor for a `val`/`type` (`#val-x`/`#type-x`).
  `<<a_manual chapter=c [fragment=f]|text>>` becomes a relative link to the
  sibling manual page (`c.html[#f]`) — robust for hyphenated chapters, section
  anchors and same-side, and valid on both ocaml.org and ocsigen.org; with
  `project=` it links to that project's manual. Headings are
  normalised so each page emits a single level-0 title (`{0}`): a second
  top-level heading is demoted, and a page without one promotes its first
  heading. A leading `@@id="x"@@` anchor on a heading becomes an odoc heading
  label (`{N:x ...}`) so cross-page fragment references resolve. Output is meant
  to be reviewed by hand.
- `Assemble`: build a full page — extract the odoc parts, render the content
  fragment (never the template chrome), fill a project-provided template
  (holes `{{title}}`/`{{preamble}}`/`{{toc}}`/`{{content}}`), mark the current
  navigation entry via `data-wodoc-page`. `?preamble` toggles the page title;
  `?flat` concatenates the inner preamble and content for full-width pages whose
  containers span the odoc preamble/content boundary. The chrome stays in the
  project, wodoc stays generic.
- `Nav`: render a project's API module navigation from a curated odoc index
  (`{N title}` sections + `{!modules: …}` lists) — used by `wodoc build` for a
  client/server project's per-side module list. A manual's own navigation is
  declared in the `doc/wodoc` config (the `(nav …)` stanza), not from a
  wikicréole menu.
- `Resolve`: link references odoc left dead — cross-package "sibling" references
  built in the same tree, and cross-project references to other hosted projects —
  rewriting the HTML in place. A hosted project declares its deployed layout
  (`multilib` / `root` / `subdir`); a `subdir` entry rewrites links to a
  multi-package project (e.g. `js_of_ocaml`, `tyxml`) into its per-package
  `<pkg>/` subtree and matches the whole opam family (`js_of_ocaml-lwt`, …).
- `Config` / `Build` / `wodoc build`: the turn-key command. From one declarative
  `doc/wodoc` config it runs `dune build @doc` and assembles a project's whole
  site (shared menu, generated left navigation and version selector, sibling
  reference resolution, assets and version redirect), replacing a hand-written
  build script and its navigation HTML. The left navigation is declared in the
  config's `(nav (section …) (api-section …) (link …))` stanza (there is no
  `menu.wiki`): manual `(section …)` blocks are shared even by client/server
  projects. `(group <heading> …)` nests sub-headings for a multi-level menu;
  `(link)` paths that are absolute (`/…`) or URLs are emitted verbatim. A
  project whose versions have different manuals passes a per-version nav with
  `wodoc build --nav <file>` (same `(nav …)` syntax). In direct-mld mode, a
  `files/` directory next to the pages (`<mld-dir>/files`) is copied verbatim to
  the site root, so pages referencing `files/…` (images, examples) resolve. The
  version selector shows `dev` first
  then the versions newest-first (numeric), labels the `latest` target
  `"<v> (latest)"`, and is rebuilt on load from a `versions.json` manifest at the
  project root (regenerated by every build/release) so frozen pages stay current.
  The page stylesheets are set by `(css <href> …)`: relative hrefs are copied into
  each build and linked per-version, giving a self-contained site that works at
  any deploy path; it defaults to the Ocsigen-hosted `/css/style.css` and
  `/css/ocsigen-odoc.css`.
- `Blog` / `(blog …)`: an ultra-simple blog. A post is a plain `.mld` named
  `YYYY-MM-DD-slug.mld` (the date prefix is the publication date, so posts sort
  newest-first with no metadata file); the author is odoc's `@author`, the title
  the page heading, the excerpt the first body paragraph. `wodoc build` builds
  each post like any page, auto-lists them in a generated left-nav section, and
  expands a landing marker (`{%html:<!--wodoc-blog-latest-->%}`, or
  `{%wodoc:blog-latest%}` in preprocessed builds) into a styled "latest posts"
  list (`.wodoc-blog-list`/`-card`/`-title`/`-meta`/`-excerpt`). Generic — no
  project-specific assumptions; styled from the project's own stylesheet. A page
  built through the low-level `wodoc assemble` path (e.g. a separately built site
  home) can carry the same listing with `--blog-config`/`--blog-base`. For such a
  build, `wodoc blog-nav` prints the left-nav block and `wodoc blog-feed` prints
  an Atom feed of the posts (syndication, e.g. OCaml Planet).
- Markdown twin & `llms.txt`: alongside the HTML, `wodoc build` emits a Markdown
  twin of every page (odoc's markdown backend) and an `llms.txt`/`llms-full.txt`
  index per project, so the docs stay readable by plain-text tools and LLMs. Each
  HTML page advertises its twin with `<link rel="alternate" type="text/markdown">`
  (low-level: `wodoc assemble --mdlink`). On by default; `(markdown false)` in the
  config turns it off.
- `wodoc requalify-xrefs`: post-pass over a co-located multi-project site that
  fixes flat cross-project links to a wrapped library (`Eliom_content` →
  `Eliom/Content`) — `odoc_driver --remap` names the reference by the flat path
  while the qualified project deploys it under its wrapper; the non-uniform
  mapping (renamed vs kept module names) is resolved by probing the target tree.
- `wodoc release`: the stable-version release procedure — freeze the CI-built
  `dev/` as `<version>/`, repoint the `latest` symlink and refresh the
  `versions.json` manifest (the only file a release rewrites; the CI only
  rebuilds `dev/`, and releases are frozen snapshots of it).
- Tests: cram suites for the converter, the renderer, the release procedure and
  the blog (end-to-end `wodoc build`).
- Documentation: a README describing the approach, the pipeline and the
  authoring rules.
- Distributed under the MIT license.
