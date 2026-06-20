# wodoc starter

A copy-paste starting point for building a complete documentation **website** for
your own (non-Ocsigen) project with [wodoc](../../README.md). It gives you the
three things `wodoc build` does not generate for you — a top menu, a stylesheet,
and a deploy workflow — so you can go from `dune build @doc` to a themed,
versioned, deployable site.

For the full walkthrough see the **Building a complete site** page of the wodoc
manual ([`manual/building-a-site.mld`](../../manual/building-a-site.mld)).

## What's here

| File | Goes to | Purpose |
|---|---|---|
| [`wodoc`](wodoc) | `doc/wodoc` | the declarative build config (project, packages, landing, nav) |
| [`menu.html`](menu.html) | `doc/menu.html` | the top-menu fragment injected as `{{menu}}` (passed via `--menu`) |
| [`css/style.css`](css/style.css) | `doc/css/style.css` | page layout + chrome theme (shipped into each build) |
| [`css/ocsigen-odoc.css`](css/ocsigen-odoc.css) | `doc/css/ocsigen-odoc.css` | the odoc **content** theme (shipped into each build) |
| [`deploy.yml`](deploy.yml) | `.github/workflows/doc.yml` | build + publish to `gh-pages` |

## Quick start

1. Copy the files into your project:

   ```
   mkdir -p doc/css
   cp examples/starter/wodoc        doc/wodoc
   cp examples/starter/menu.html    doc/menu.html
   cp examples/starter/css/*.css    doc/css/
   cp examples/starter/deploy.yml   .github/workflows/doc.yml
   ```

2. Edit `doc/wodoc`: set `(project …)`, `(title …)`, `(url-prefix …)`, `(packages …)`,
   the `(landing …)` page and the `(nav …)` entries to your project.

3. Build and preview the site locally:

   ```
   wodoc build --config doc/wodoc --out _site/dev --label dev --menu doc/menu.html
   (cd _site && python3 -m http.server)
   # then open http://localhost:8000/dev/
   ```

   The theme is shipped inside `_site/dev/` and linked relatively, so it just
   works — no assets to host separately.

## Self-contained by default (works at any path)

The starter config sets the theme with **relative** paths
(`(css css/style.css css/ocsigen-odoc.css)`), so wodoc copies the stylesheet into
each build and links it per-version. The highlighter is local too
(`(highlight wodoc-highlight.js)`). The result is a **self-contained** site that
works wherever you serve it — including a plain GitHub project page
(`you.github.io/PROJECT/`). Just set `(url-prefix /PROJECT)` to match the path the site
is served at, so the version selector switches correctly.

If you instead omit `(css …)`, wodoc falls back to the Ocsigen-hosted defaults
(`/css/style.css`, `/css/ocsigen-odoc.css`) — absolute paths that then require you
to serve `/css/` at the **domain root** (a `you.github.io` user/org site or a
custom domain).

## Releasing a version

CI deploys `dev/` on every push. To freeze a release and make it the default:

```
# from a checkout of the gh-pages branch (or via the workflow's manual run):
wodoc release --site . --version 1.0.0
```

This copies `dev/` to `1.0.0/`, repoints the `latest` symlink and refreshes
`versions.json` (the manifest that drives the version `<select>`). The
`workflow_dispatch` run in `deploy.yml` does the equivalent from the Actions tab
(set *label* to the version, *ref* to the tag, tick *set_latest*).
