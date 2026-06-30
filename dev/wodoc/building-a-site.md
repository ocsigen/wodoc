
# Building a complete site

odoc gives you an API reference. wodoc turns the same sources into a **complete website**: a styled home page, prose chapters, the API of one or several packages, a shared top menu, a generated left navigation, a version selector, an optional blog, Markdown twins for AI tools, and a deployable versioned tree — all from one declarative [`doc/wodoc`](./config.md) config and a single `wodoc build`.

This page is the end-to-end walkthrough. It assumes you have read [How it works](./overview.md) and points to [Configuration](./config.md) and [Commands](./commands.md) for the exhaustive reference of every stanza and flag. A **copy-paste starter** (a menu, a stylesheet and a CI workflow) lives in [`examples/starter`](https://github.com/ocsigen/wodoc/tree/master/examples/starter) — clone it and adjust the names rather than starting from a blank page.


## Quickstart

From an existing dune project with a public library (say package `demo`, whose top module is `Demo`, with documented `.mli`), three steps give you a styled site.


### 1\. Add a documentation page

odoc builds the `.mld` pages of a package declared with a `(documentation …)` stanza:

```text
mkdir doc
cat > doc/dune <<'EOF'
(documentation (package demo))
EOF
cat > doc/index.mld <<'EOF'
{0 Demo}

Welcome to {b Demo}. See the {!Demo} API.
EOF
```

### 2\. Write the wodoc config

```text
cat > doc/wodoc <<'EOF'
(project demo)
(title "Demo")
(url-prefix /demo)
(packages demo)
(landing demo/index.html)
(nav
 (section "Manual" (link "Home" demo/index.html index))
 (api-section "API" (link "Demo" demo/Demo/index.html Demo)))
EOF
```

### 3\. Build and preview

```text
wodoc build --config doc/wodoc --out _site/dev --label dev
# the result is in _site/
```
`wodoc build` runs `dune build @doc` itself and assembles every page. The result is a complete, **styled, self-contained** site — no menu file, no stylesheet to host. (Customise later with `--menu` and `(css …)`; see [Theming](./#theming).)


### Add a blog

Write a dated post — the filename date is the publication date, `@author` the author, the first heading the title, the first paragraph the excerpt:

```text
mkdir doc/blog
cat > doc/blog/2026-01-15-hello.mld <<'EOF'
{0 Hello, world}

@author Jane Doe

Our very first post, announcing the demo.
EOF
```
Declare the blog in `doc/wodoc` and drop a "latest posts" marker on the landing (`{%html:<!--wodoc-blog-latest-->%}` is the form that survives odoc):

```text
# append to doc/wodoc:
(blog (dir blog) (out blog) (heading "Blog") (latest 5))
```
```text
# add to doc/index.mld where the list should appear:
{1 Latest posts}
{%html:<!--wodoc-blog-latest-->%}
```
Rebuild with the same `wodoc build` command: the post is built at `blog/`, listed in a generated left-nav section, and the marker expands into a styled list. See [Adding a blog](./blog.md) for the Atom feed and the navigation block.


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

`wodoc build --out <dir> --label <v>` writes *one version* of the site into `<dir>`. Deployed, the tree looks like this (here `(url-prefix /myproj)`, one package):

```text
/myproj/
  dev/                 <- a build (--label dev)
    index.html         <- redirect to the landing page
    myproj/            <- the package's pages (manual + API)
      index.html       <- the home page
      tutorial.html
      Myproj/index.html
    wodoc.css          <- the theme (built-in default, or your (css …))
    wodoc-highlight.js
    versions.json      <- the version manifest (drives the <select>)
  1.0.0/               <- a frozen release (wodoc release)
  latest -> 1.0.0      <- a symlink
```
Everything a page references — the theme, the highlighter, internal links — is version-relative, so the site is self-contained and a frozen version keeps working forever. (Only the version `<select>` uses the absolute `(url-prefix)` to switch versions.)


## `wodoc build`: what it generates, what you supply

The turn-key [`wodoc build`](./commands.md) runs `dune build @doc` and then assembles every page. It **generates almost everything** — including a default theme and top bar — so a basic site needs no theming setup at all.

| Part | Who provides it |
| --- | --- |
| the HTML page template (head, two-column body, scripts) | **generated** |
| the left navigation, "on this page", version `<select>` and its script | **generated** (from the config) |
| the page content (odoc HTML, with your `{%wodoc:…%}` markers rendered) | **generated** |
| Markdown twins, `llms.txt`, the landing redirect, `versions.json` | **generated** |
| the highlighter (`highlight.pack.js` and `wodoc-highlight.js`) | **shipped** by wodoc |
| the **top bar** | **generated** default; override with `--menu` (a file or URL) |
| the **stylesheet / theme** | **shipped** default `wodoc.css`; override with `(css …)` |
| static assets (images, examples) | **you** (via config; see below) |
So the minimal build is just:

```text
wodoc build --config doc/wodoc --out _site/dev --label dev
```
That already produces a **styled, self-contained site** — a built-in theme and a top bar are shipped and linked by per-version relative paths, so it works at any deploy path. The rest of this page is about the pieces you may want to customise: the home page, the navigation, and — when you outgrow the built-in look — the theme and the top bar.


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
A **client/server** project (libraries that share module names, e.g. an Eliom app) is built through `odoc_driver` instead of `dune build @doc`. Just declare a `(client-server …)` block (it implies `(odoc-driver <project>)`); wodoc then gives every page its side's API nav, a body colour and a client/server switch. See the `(client-server …)` stanza in [Configuration](./config.md).


## Theming: customising the look

`wodoc build` ships a built-in theme and a default top bar (the section above), so you can skip this entirely and still get a styled site. Customise when you outgrow the defaults.


### The top bar (`--menu`)

Pass `--menu <file|URL>` to replace the default bar with your own HTML *fragment* (a local file or an `http(s)` URL fetched with curl), injected at the top of every page. It may contain holes wodoc fills: `{{subproject}}` (your title) and `{{base}}` (the per-page relative path to the version root). A minimal menu:

```text
<header class="site-header">
  <a class="site-brand" href="/">My Project</a>
  {{subproject}}
  <nav class="site-nav"><a href="{{base}}/index.html">Docs</a></nav>
</header>
```

### The stylesheet (`(css …)`)

By default wodoc links its built-in theme (`wodoc.css`, shipped per-version). The `(css …)` stanza replaces it; the template does *not* link odoc's own `odoc.css`, so your stylesheets carry the whole look. Choose how they are served:

- `(css style.css …)` — **relative** hrefs: wodoc copies each file (found next to the config) into every build and links it per-version, so the site stays **self-contained** and works at any deploy path;
- `(css /css/style.css …)` or a full URL — **absolute** hrefs, emitted verbatim, which you serve yourself (e.g. a shared site-wide stylesheet at the domain root).
A custom stylesheet must style both the chrome and the content:

- the chrome wodoc emits — `.wodoc-page`, `.project-page`/`.twocols`/`.leftcol`/ `.rightcol`, the navigation (`.api-nav`, `.api-section`, `.ml2`/`.ml3`/…, `li.current`), `.docversion`/`.wodoc-version`, `.page-toc`, `.cs-switch` and the blog `.wodoc-blog-*` classes;
- the odoc **content** — `.odoc-preamble`/`.odoc-content`, headings, code blocks (highlight.js `.hljs-*` tokens), tables and declaration specs.
The [starter stylesheet](https://github.com/ocsigen/wodoc/tree/master/examples/starter/css) covers all of these — copy it and recolour. (If you would rather reuse odoc's stock theme for the content, note that `odoc.css` *is* shipped next to each version, so you can link or `@import` it from your `/css/ocsigen-odoc.css`.)

Syntax highlighting: wodoc ships `wodoc-highlight.js` in every build and the page template always loads it *version-relatively* (`{{base}}/wodoc-highlight.js`), so a frozen version keeps the highlighter it was built with. By default this is wodoc's built-in starter (it teaches odoc's bundled `highlight.js` the eliom / lwt / js\_of\_ocaml syntax extensions). `(highlight <file>)` only changes *which* file is shipped under that name, not where it is loaded from: set it for a project whose code blocks use yet another syntax.


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
Deploy the tree to GitHub Pages (or any static host). With a **relative** `(css …)` theme and a local `(highlight …)` (as in the starter), the site is self-contained and deploys at **any path** — a `you.github.io` site, a custom domain, or a plain project page (`you.github.io/PROJECT/`) — as long as `(pub)` matches the path it is served at (so the version selector switches correctly). If you keep the *absolute* stylesheet default instead, then `/css/` must be served at the **domain root** (a user/org site or a custom domain), since `you.github.io/PROJECT/` would resolve `/css/…` outside your repo.

Worked CI examples:

- a generic gh-pages workflow: [`examples/starter/deploy.yml`](https://github.com/ocsigen/wodoc/blob/master/examples/starter/deploy.yml);
- wodoc's own (it dogfoods itself): [`.github/workflows/doc.yml`](https://github.com/ocsigen/wodoc/blob/master/.github/workflows/doc.yml) and [`doc/README.md`](https://github.com/ocsigen/wodoc/blob/master/doc/README.md).

## A copy-paste starter

Rather than assemble the menu, stylesheet and workflow by hand, start from [`examples/starter`](https://github.com/ocsigen/wodoc/tree/master/examples/starter): copy `wodoc`, `menu.html`, `css/` and `deploy.yml` into your project, change the names, and you have a themed, versioned, deployable site. Its [README](https://github.com/ocsigen/wodoc/blob/master/examples/starter/README.md) is the five-minute version of this page.
