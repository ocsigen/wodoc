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
| [`css/style.css`](css/style.css) | served at `/css/style.css` | page layout + chrome theme |
| [`css/ocsigen-odoc.css`](css/ocsigen-odoc.css) | served at `/css/ocsigen-odoc.css` | the odoc **content** theme |
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

2. Edit `doc/wodoc`: set `(project …)`, `(title …)`, `(pub …)`, `(packages …)`,
   the `(landing …)` page and the `(nav …)` entries to your project.

3. Build the site locally:

   ```
   wodoc build --config doc/wodoc --out _site/dev --label dev \
               --menu doc/menu.html --local
   ```

   `--local` fetches nothing here (your assets are local), but it prints the exact
   command to preview the site — because the pages use absolute paths (`/css/…`),
   serve the **parent** of the version directory and put the CSS at its root:

   ```
   cp -r doc/css _site/css
   (cd _site && python3 -m http.server)
   # then open http://localhost:8000/dev/
   ```

## The one thing to know: `/css/` lives at the domain root

The page template wodoc generates links the stylesheet by **absolute** path
(`/css/style.css`, `/css/ocsigen-odoc.css`). So the CSS must be reachable at the
**root of the domain**, not under your project's path. In practice:

- **Works:** a user/org pages site (`you.github.io`) or a project repo with a
  **custom domain** (a `CNAME`), where gh-pages is served at the domain root. The
  `deploy.yml` here publishes both the version directories and `/css/` at that
  root.
- **Does not work out of the box:** a plain project page
  (`you.github.io/PROJECT/`), where `/css/…` resolves to `you.github.io/css/`
  (outside your repo). Use a custom domain, or host the two CSS files at whatever
  serves your domain root.

The same applies to the version selector (it switches on the absolute `(pub)`
prefix) and to the default highlighter — which is why the starter config sets
`(highlight wodoc-highlight.js)` to ship a **local** copy instead of the
Ocsigen-hosted `/doc/wodoc-highlight.js`.

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
