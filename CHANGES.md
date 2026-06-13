# Changes

## Unreleased

First release: an odoc driver that builds complete, styled websites from `.mld`
and `.mli` sources. It provides:

- `Preprocess`: rewrite `{%wodoc:..%}` markers into `{%html:<!--wodoc:..-->%}`
  so stock odoc preserves them as HTML comments.
- `Render`: turn the markers in odoc's HTML output into real, correctly nested
  HTML — containers (`div`/`a`/`span`/`end`), multi-level attribute injection
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
- `Nav`: build a left-column navigation fragment from a manual's wikicréole menu,
  a curated API module index, or a single page's in-page anchors.
- `Resolve`: link references odoc left dead — cross-package "sibling" references
  built in the same tree, and cross-project references to other hosted projects —
  rewriting the HTML in place.
- `Config` / `Build` / `wodoc build`: the turn-key command. From one declarative
  `doc/wodoc` config it runs `dune build @doc` and assembles a project's whole
  site (shared menu, generated left navigation and version selector, sibling
  reference resolution, assets and version redirect), replacing a hand-written
  build script and its navigation HTML.
- `wodoc release`: the stable-version release procedure — freeze the CI-built
  `dev/` as `<version>/` and repoint the `latest` symlink (the CI only rebuilds
  `dev/`; releases are frozen snapshots of it).
- Tests: cram suites for the converter, the renderer and the release procedure.
- Documentation: a README describing the approach, the pipeline and the
  authoring rules.
- Distributed under the MIT license.
