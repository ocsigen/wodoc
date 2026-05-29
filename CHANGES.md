# Changes

## Unreleased

- Initial project skeleton: `wodoc` library and CLI.
- `Preprocess`: rewrite `{%wodoc:..%}` markers into `{%html:<!--wodoc:..-->%}`
  so stock odoc preserves them as HTML comments.
- `Render`: turn the markers in odoc's HTML output into real, correctly nested
  HTML — containers (`div`/`a`/`span`/`end`), attribute injection on the next
  element (`@`, the `@@` equivalent), and self-contained images (`img`). Hoists
  structural tags out of odoc's forced `<p>` wrappers.
