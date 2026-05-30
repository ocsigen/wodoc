# Changes

## Unreleased

- License: MIT (was LGPL-2.1); add a `LICENSE` file.
- Initial project skeleton: `wodoc` library and CLI.
- `Preprocess`: rewrite `{%wodoc:..%}` markers into `{%html:<!--wodoc:..-->%}`
  so stock odoc preserves them as HTML comments.
- `Render`: turn the markers in odoc's HTML output into real, correctly nested
  HTML — containers (`div`/`a`/`span`/`end`), multi-level attribute injection
  (`@ S0 | S1 | S2`, html_of_wiki's `@@` equivalent: successive nesting levels — e.g.
  table / row / cell — mirroring html_of_wiki's `@@a@b@c@@`), and self-contained
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
  becomes a highlighted code block, and indented headings/lists are recognised.
  `<<a_api [text=..]|module M / val M.f>>` becomes an odoc reference
  (`{!M}` / `{{!M}text}`) and `<<a_manual chapter=c [fragment=f]|text>>` becomes
  a page reference (`{{!page-c}text}` / `{{!page-c.f}text}`). Headings are
  normalised so each page emits a single level-0 title (`{0}`): a second
  top-level heading is demoted, and a page without one promotes its first
  heading. A leading `@@id="x"@@` anchor on a heading becomes an odoc heading
  label (`{N:x ...}`) so cross-page fragment references resolve. Output is meant
  to be reviewed by hand.
- Tests: cram suite for the converter (`test/convert.t`).
- `Assemble`: build a full page — extract the odoc parts, render the content
  fragment (never the template chrome), fill a project-provided template
  (holes `{{title}}`/`{{preamble}}`/`{{toc}}`/`{{content}}`), mark the current
  navigation entry via `data-wodoc-page`. `?preamble` toggles the page title;
  `?flat` concatenates the inner preamble and content for full-width pages whose
  containers span the odoc preamble/content boundary. The chrome stays in the
  project, wodoc stays generic.
- Docs: explain in the README why the markers are rewritten to HTML comments
  (a trick to carry them through odoc, which otherwise drops unknown raw markup).
