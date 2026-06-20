# wodoc starter

A copy-paste starting point for a complete documentation **website** with
[wodoc](../../README.md). The default path is zero-config: `wodoc build` ships a
theme and a top bar, so you go from `dune build @doc` to a themed, versioned,
deployable site with just a config and a CI workflow. The `menu.html` and `css/`
files here are *optional* examples, for when you want your own look.

For the full walkthrough see the **Building a complete site** page of the wodoc
manual ([`manual/building-a-site.mld`](../../manual/building-a-site.mld)).

## What's here

| File | Goes to | Purpose |
|---|---|---|
| [`wodoc`](wodoc) | `doc/wodoc` | the declarative build config (project, packages, landing, nav) |
| [`deploy.yml`](deploy.yml) | `.github/workflows/doc.yml` | build + publish to `gh-pages` |
| [`menu.html`](menu.html) | `doc/menu.html` | *optional* — a custom top-bar fragment (use with `--menu`) |
| [`css/`](css) | `doc/css/` | *optional* — a custom theme (use with the `(css …)` stanza) |

## Quick start

1. Copy the config and workflow into your project:

   ```
   cp examples/starter/wodoc      doc/wodoc
   cp examples/starter/deploy.yml .github/workflows/doc.yml
   ```

2. Edit `doc/wodoc`: set `(project …)`, `(title …)`, `(url-prefix …)`,
   `(packages …)`, the `(landing …)` page and the `(nav …)` entries.

3. Build and preview:

   ```
   wodoc build --config doc/wodoc --out _site/dev --label dev
   (cd _site && python3 -m http.server)
   # then open http://localhost:8000/dev/
   ```

   The built-in theme and top bar are shipped inside `_site/dev/` and linked
   relatively, so the site is self-contained and works at any deploy path —
   including a plain GitHub project page (`you.github.io/PROJECT/`); just set
   `(url-prefix /PROJECT)` so the version selector switches correctly.

## Customising the theme and menu (optional)

To replace the built-in look, copy the example assets next to your config:

```
mkdir -p doc/css
cp examples/starter/menu.html doc/menu.html
cp examples/starter/css/*.css doc/css/
```

Then uncomment `(css css/style.css css/ocsigen-odoc.css)` in `doc/wodoc`
(relative paths are copied per-version, keeping the site self-contained) and add
`--menu doc/menu.html` to the build command. Absolute `(css /css/…)` hrefs are
emitted verbatim instead — then you serve `/css/` at the domain root yourself.

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
