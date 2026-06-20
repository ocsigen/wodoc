
# Building a complete site

odoc gives you an API reference. wodoc turns the same sources into a **complete website**: a styled home page, prose chapters, the API of one or several packages, a shared top menu, a generated left navigation, a version selector, an optional blog, Markdown twins for AI tools, and a deployable versioned tree — all from one declarative [`doc/wodoc`](./config.md) config and a single `wodoc build`.

This page is the end-to-end walkthrough. It assumes you have read [How it works](./overview.md) and points to [Configuration](./config.md) and [Commands](./commands.md) for the exhaustive reference of every stanza and flag. A **copy-paste starter** (a menu, a stylesheet and a CI workflow) lives in [`examples/starter`](https://github.com/ocsigen/wodoc/tree/master/examples/starter) — clone it and adjust the names rather than starting from a blank page.


## What "a complete website" means

A wodoc site is made of these ingredients; each is covered below.

- a **home / landing page** — your styled front page, not the bare API index;
- **prose pages** — chapters, tutorials, guides (plain `.mld` files);
- the **API** — the `.mli` of one package, or several packages side by side;
- a **top menu** — the site-wide header (your brand, links), shared by every page;
- a **left navigation** — generated from the config, with the current entry marked;
- a **version selector** — `dev`, released versions and `latest`, from a manifest;
- a **theme** — the stylesheet that makes all of the above look like a site;
- optionally a **blog** and **Markdown twins** for AI tools;
- a **deployment** — a versioned tree published to (typically) GitHub Pages.

## The shape of a built site

`wodoc build --out <dir> --label <v>` writes *one version* of the site into `<dir>`. Deployed, the tree looks like this (here `(pub /myproj)`, one package):

```text
/myproj/
  dev/                 <- a build (--label dev)
    index.html         <- redirect to the landing page
    myproj/            <- the package's pages (manual + API)
      index.html       <- the home page
      tutorial.html
      Myproj/index.html
    wodoc-highlight.js
    versions.json      <- the version manifest (drives the <select>)
  1.0.0/               <- a frozen release (wodoc release)
  latest -> 1.0.0      <- a symlink
/css/                  <- the stylesheet, at the DOMAIN ROOT (see Theming)
```
Internal links are version-relative, so a frozen version keeps working forever; only the version `<select>`, the stylesheet and the highlighter are referenced by absolute path. Remember that last point — it shapes deployment (see [Versioning and deployment](./#deployment)).


## `wodoc build`: what it generates, what you supply

The turn-key [`wodoc build`](./commands.md) runs `dune build @doc` and then assembles every page. It **generates almost everything**; you supply only the top menu and the stylesheet.

| Part | Who provides it |
| --- | --- |
| the HTML page template (head, two-column body, scripts) | **generated** |
| the left navigation, "on this page", version `<select>` and its script | **generated** (from the config) |
| the page content (odoc HTML, with your `{%wodoc:…%}` markers rendered) | **generated** |
| Markdown twins, `llms.txt`, the landing redirect, `versions.json` | **generated** |
| the highlighter (`highlight.pack.js` and `wodoc-highlight.js`) | **shipped** by wodoc |
| the **top menu** fragment (`--menu`) | **you** (a file or URL) |
| the **stylesheet** (`/css/style.css`, `/css/ocsigen-odoc.css`) | **you** (host it at the root) |
| static assets (images, examples) | **you** (via config; see below) |
So a minimal build is:

```text
wodoc build --config doc/wodoc --out _site/dev --label dev --menu doc/menu.html
```
`--menu` is **required**. The rest of this page is about filling in the two columns you own.


## The home page

The landing page is just one of your `.mld` pages, assembled like any other — so you style it with the full [directive set](./directives.md) (`{%wodoc:div%}`, `{%wodoc:@ class=…%}`, `{%wodoc:img%}`, the semantic block containers…) to make a real front page rather than a wall of text.

Point the config's `(landing …)` stanza at it:

```text
(landing myproj/index.html)
```
`wodoc build` then writes a tiny `index.html` at the version root that redirects to that page, so `/myproj/dev/` lands on your home page. (A [manual-only project](./config.md) whose landing *is* the root `index.html` gets a real page there instead of a redirect.)


## General (prose) pages

Any `.mld` file compiled by `dune build @doc` becomes a page: write chapters, tutorials and guides as ordinary odoc pages and list them in the navigation (next section). Keep them **portable** — see [Authoring](./authoring.md) for which constructs survive on ocaml.org and which are wodoc-only chrome. Migrating an old wikicréole manual? Run [`wodoc convert`](./commands.md) once to bootstrap the `.mld` files, then review them.


## The left navigation

The left column is declared, not hand-written, in the config's `(nav …)` stanza:

```text
(nav
 (section "Manual"
  (link "Overview" myproj/index.html index)
  (link "Tutorial" myproj/tutorial.html tutorial)
  (group "Advanced"
   (link "Internals" myproj/internals.html internals)))
 (api-section "API"
  (link "API overview" myproj/Myproj/index.html Myproj)))
```
Each `(link "Label" <path> <id>)` gives the visible label, a version-relative path and the page's odoc `<id>` — wodoc marks the matching entry `current` on each page automatically (longest-prefix match, so you never hand-maintain "current" flags). `(group …)` nests a sub-heading; `(section …)` is a manual block, `(api-section …)` an API block. A project whose versions have *different* manuals can pass a per-version navigation with `wodoc build --nav <file>` (same syntax). The full grammar is in [Configuration](./config.md).


## API docs: one package or several

For a single library, `(packages myproj)` assembles its `dune build @doc` output. List several to document them side by side:

```text
(packages myproj myproj-lwt myproj-unix)
```
A **client/server** project (libraries that share module names, e.g. an Eliom app) is built through `odoc_driver` instead of `dune build @doc` — declare it with `(odoc-driver <pkg>)` and a `(client-server …)` block; wodoc then gives every page its side's API nav, a body colour and a client/server switch. See the `(client-server …)` and `(odoc-driver …)` stanzas in [Configuration](./config.md).


## Theming: the menu and the stylesheet

This is the part you must set up yourself, and — for now — the fiddliest one.


### The top menu (`--menu`)

`--menu` takes an HTML *fragment* (a local file or an `http(s)` URL fetched with curl) that wodoc injects at the top of every page. It may contain holes wodoc fills: `{{subproject}}` (your title) and `{{base}}` (the per-page relative path to the version root). A minimal menu is just your header markup:

```text
<header class="site-header">
  <a class="site-brand" href="/">My Project</a>
  {{subproject}}
  <nav class="site-nav"><a href="{{base}}/index.html">Docs</a></nav>
</header>
```

### The stylesheet

The generated template links **two stylesheets by absolute path**, `/css/style.css` and `/css/ocsigen-odoc.css`, and does *not* link odoc's own `odoc.css`. So nothing is styled until you provide those two files and host them at the site's **domain root**. They must style:

- the chrome wodoc emits — `.wodoc-page`, `.project-page`/`.twocols`/`.leftcol`/ `.rightcol`, the navigation (`.api-nav`, `.api-section`, `.ml2`/`.ml3`/…, `li.current`), `.docversion`/`.wodoc-version`, `.page-toc`, `.cs-switch` and the blog `.wodoc-blog-*` classes;
- the odoc **content** — `.odoc-preamble`/`.odoc-content`, headings, code blocks (highlight.js `.hljs-*` tokens), tables and declaration specs.
The [starter stylesheet](https://github.com/ocsigen/wodoc/tree/master/examples/starter/css) covers all of these — copy it and recolour. (If you would rather reuse odoc's stock theme for the content, note that `odoc.css` *is* shipped next to each version, so you can link or `@import` it from your `/css/ocsigen-odoc.css`.)

Syntax highlighting: wodoc always ships `wodoc-highlight.js` in each build, but the template only loads it locally when the config sets `(highlight <file>)` — otherwise it loads the shared `/doc/wodoc-highlight.js`. Set `(highlight wodoc-highlight.js)` (the starter does) so your site uses its own local copy.


## Several projects that cross-link

A site can host several *independent* projects (each its own `wodoc build`, deployed into a shared tree) whose docs cross-reference each other. odoc points such cross-references at ocaml.org; the `(hosted …)` stanza rewrites them into relative links to the sibling project, given how that project is deployed:

```text
(hosted (myproj myproj multilib Myproj)
        (otherproj otherproj root "")
        (bigproj bigproj subdir ""))
```
The layout token is `multilib` (one `<pkg>.<lib>/` subtree per library), `root` (a single package at the version root) or `subdir` (a `<pkg>/` subtree per package, e.g. js\_of\_ocaml, tyxml). See `(hosted …)` in [Configuration](./config.md) and [`wodoc requalify-xrefs`](./commands.md).


## A blog

Drop dated `.mld` posts (`YYYY-MM-DD-slug.mld`) in a directory, add a `(blog …)` stanza, and `wodoc build` lists them in the navigation, expands a "latest posts" widget on the landing and can emit an Atom feed for syndication. The full recipe is on its own page: [Adding a blog](./blog.md).


## Markdown and llms.txt for AI tools

By default `wodoc build` also emits, next to every HTML page, a **Markdown twin** and a per-project `llms.txt` / `llms-full.txt` index (the [llms.txt](https://llmstxt.org) convention), and adds a `<link rel="alternate" type="text/markdown">` to each page. This keeps your docs readable by plain-text tooling and LLMs at no extra effort. Turn it off with `(markdown false)` in the config.


## Versioning and deployment

A build is one version directory; releases are frozen snapshots:

- **CI builds `dev/`** on each push — `wodoc build --out _site/dev --label dev`.
- **A release freezes it**: [`wodoc release`](./commands.md) `--site <gh-pages> --version 1.0.0` copies `dev/` to `1.0.0/`, repoints the `latest` symlink and refreshes `versions.json`. Frozen pages are never rebuilt; the version `<select>` reads `versions.json` at load time, so even old pages list the current set.
Deploy the tree to GitHub Pages (or any static host). **The one constraint:** because the stylesheet (and the version-switch `(pub)` prefix, and the shared highlighter) use absolute paths, the site must be served from a **domain root** — a `you.github.io` user/org site, or a project repo with a custom domain (`CNAME`). On a plain project page (`you.github.io/PROJECT/`) the absolute `/css/…` would resolve outside your repo and 404\.

Worked CI examples:

- a generic gh-pages workflow: [`examples/starter/deploy.yml`](https://github.com/ocsigen/wodoc/blob/master/examples/starter/deploy.yml);
- wodoc's own (it dogfoods itself): [`.github/workflows/doc.yml`](https://github.com/ocsigen/wodoc/blob/master/.github/workflows/doc.yml) and [`doc/README.md`](https://github.com/ocsigen/wodoc/blob/master/doc/README.md).

## A copy-paste starter

Rather than assemble the menu, stylesheet and workflow by hand, start from [`examples/starter`](https://github.com/ocsigen/wodoc/tree/master/examples/starter): copy `wodoc`, `menu.html`, `css/` and `deploy.yml` into your project, change the names, and you have a themed, versioned, deployable site. Its [README](https://github.com/ocsigen/wodoc/blob/master/examples/starter/README.md) is the five-minute version of this page.
