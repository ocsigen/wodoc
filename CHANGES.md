# Changes

## Unreleased

- Initial project skeleton: `wodoc` library and CLI.
- `Preprocess`: rewrite `{%wodoc:..%}` markers into `{%html:<!--wodoc:..-->%}`
  so stock odoc preserves them as HTML comments.
- `Render`: turn the markers in odoc's HTML output into real, correctly nested
  HTML — containers (`div`/`a`/`span`/`end`), multi-level attribute injection
  (`@ S0 | S1 | S2`, the `@@` equivalent: successive nesting levels — e.g.
  table / row / cell — mirroring html_of_wiki's `@@a@b@c@@`), and self-contained
  images (`img`). Hoists structural tags out of odoc's forced `<p>` wrappers.
- `Assemble`: wrap rendered odoc HTML in a project-provided site template
  (holes `{{title}}`/`{{preamble}}`/`{{toc}}`/`{{content}}`, current-page marking
  via `data-wodoc-page`). The chrome stays in the project, wodoc stays generic.
