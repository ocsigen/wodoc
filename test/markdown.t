`wodoc build` emits, next to the themed HTML, the Markdown twin of every page
(for AI/LLM consumption), advertises it from each page with a
<link rel="alternate">, and writes an llms.txt index. This test feeds a canned
odoc HTML tree (--src) and its parallel markdown tree (--md-src), so it checks
wodoc's own placement/indexing without invoking odoc's backends.

  $ mkdir -p src/demo/Mod md/demo doc
  $ cat > menu.html <<'EOF'
  > <nav>{{subproject}}{{leftnav}}</nav>
  > EOF
  $ cat > doc/wodoc <<'EOF'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (packages demo)
  > (landing demo/index.html)
  > (nav
  >   (section "Manual"
  >     (link "Introduction" "demo/index.html")))
  > EOF

A canned odoc-style HTML page carries the markers Assemble extracts (preamble
with the <h1>, and the content block):

  $ canned () {
  >   printf '<html><body><header class="odoc-preamble"><h1>%s</h1></header><div class="odoc-content"><p>%s</p></div></body></html>' "$1" "$2"
  > }
  $ canned "Demo" "Welcome to the demo." > src/demo/index.html
  $ canned "Mod" "A module." > src/demo/Mod/index.html

The parallel markdown tree (flat module layout, as odoc markdown-generate emits):

  $ printf '\n# Demo\n\nWelcome to the demo.\n' > md/demo/index.md
  $ printf '\n# Module `Mod`\n\nA module.\n' > md/demo/Mod.md

  $ wodoc build --config doc/wodoc --src src --md-src md --out out/dev \
  >   --menu menu.html --label dev 2>/dev/null

The markdown twins land next to their HTML pages (the flat name is kept):

  $ test -f out/dev/demo/index.md && echo ok
  ok
  $ test -f out/dev/demo/Mod.md && echo ok
  ok

Each HTML page advertises its twin with a <link rel="alternate"> whose href
resolves to the twin (existence-checked, so it is only emitted when present):

  $ grep -o '<link rel="alternate"[^>]*>' out/dev/demo/index.html
  <link rel="alternate" type="text/markdown" href="../demo/index.md"/>
  $ grep -o '<link rel="alternate"[^>]*>' out/dev/demo/Mod/index.html
  <link rel="alternate" type="text/markdown" href="../../demo/Mod.md"/>

The llms.txt index follows the convention: an H1 project name, a blockquote
summary taken from the landing page, then a Manual and an API section listing
every page by its title:

(grep -c, since cram reads a leading `>` as a command continuation and a leading
`-` as a grep option; every count is 1.)

  $ grep -c '^# Demo$' out/dev/llms.txt
  1
  $ grep -c 'Welcome to the demo' out/dev/llms.txt
  1
  $ grep -c '^## Manual$' out/dev/llms.txt
  1
  $ grep -c '^## API$' out/dev/llms.txt
  1
  $ grep -cF 'Demo](demo/index.md)' out/dev/llms.txt
  1
  $ grep -cF 'Mod`](demo/Mod.md)' out/dev/llms.txt
  1

llms-full.txt concatenates every page for single-shot ingestion:

  $ grep -c '^# ' out/dev/llms-full.txt
  3

The twins and the index are part of the site, and a version directory is
deployed wholesale, so a build that produced none of them would delete the ones
already online. A Markdown tree that is absent, or holds no page at all, stops
the build and names the way out:

  $ wodoc build --config doc/wodoc --src src --md-src gone --out bad/dev \
  >   --menu menu.html --label dev
  wodoc build: no Markdown tree at gone
  wodoc build: the Markdown twins and llms.txt are part of the site; fix the
    error above, or opt out with (markdown false) in the wodoc config.
  [1]

  $ mkdir -p hollow
  $ wodoc build --config doc/wodoc --src src --md-src hollow --out bad/dev \
  >   --menu menu.html --label dev
  wodoc build: no .md page under hollow
  wodoc build: the Markdown twins and llms.txt are part of the site; fix the
    error above, or opt out with (markdown false) in the wodoc config.
  [1]

A project can opt out of the whole Markdown pipeline with (markdown false): no
.md twins, no llms.txt, and no <link rel="alternate"> on the pages.

  $ printf '(project demo)\n(title Demo)\n(url-prefix /demo)\n(packages demo)\n(landing demo/index.html)\n(markdown false)\n' > doc/wodoc
  $ wodoc build --config doc/wodoc --src src --md-src gone --out off/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ test -e off/dev/demo/index.md && echo twin || echo "no twin"
  no twin
  $ test -e off/dev/llms.txt && echo index || echo "no index"
  no index
  $ grep -c 'rel="alternate"' off/dev/demo/index.html
  0
  [1]

odoc's Markdown backend has no remap: a reference into another package is a
link relative to odoc's output tree, one directory per package, which leads
nowhere once deployed. The twin gets the target the HTML gets: the deployed
twin of a hosted project (in its dev docs, for a dev build), else the
package's documentation on ocaml.org, at the version the HTML links to.

  $ mkdir -p xsrc/demo xmd/demo
  $ printf '(project demo)\n(title Demo)\n(url-prefix /demo)\n(packages demo)\n(landing demo/index.html)\n(hosted (tyxml tyxml subdir))\n' > doc/wodoc
  $ canned "Demo" '<a href="https://ocaml.org/p/react/1.2.2/doc/React/index.html">React</a>' \
  >   > xsrc/demo/index.html
  $ printf '\n# Demo\n\nSee [the PPX](./../tyxml/ppx.md), [React](./../react/react/React.md#val-s) and [Mod](./Mod.md).\n' \
  >   > xmd/demo/index.md
  $ wodoc build --config doc/wodoc --src xsrc --md-src xmd --out x/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ grep -o '([^)]*)' x/dev/demo/index.md
  (../../../tyxml/dev/tyxml/ppx.md)
  (https://ocaml.org/p/react/1.2.2/doc/react/React/index.html#val-s)
  (./Mod.md)

A release freezes the dev docs; the twins then link to the latest docs of the
hosted projects too:

  $ wodoc release --site x --version 1.0 2>/dev/null
  $ grep -o '([^)]*tyxml[^)]*)' x/1.0/demo/index.md
  (../../../tyxml/latest/tyxml/ppx.md)

`llms-full.txt` concatenates the twins of pages of every depth (and starts
with the landing page's summary); their links are pinned too:

  $ grep -c 'tyxml/dev/' x/dev/llms-full.txt
  2
  $ grep -o '([^)]*tyxml[^)]*)' x/1.0/llms-full.txt
  (../../../tyxml/latest/tyxml/ppx.md)
  (../../../tyxml/latest/tyxml/ppx.md)

The Markdown tree of `dune build @doc`, like that of a multi-package odoc-driver
build, starts with odoc's package list, `index.md`, which is no page of the
manual: like its HTML page, it is left out.

  $ mkdir -p rsrc/demo rmd/demo
  $ printf '(project demo)\n(title Demo)\n(url-prefix /demo)\n(packages demo)\n(landing demo/index.html)\n' > doc/wodoc
  $ canned "Demo" "Welcome to the demo." > rsrc/demo/index.html
  $ printf '\n# Demo\n\nWelcome to the demo.\n' > rmd/demo/index.md
  $ printf '\n# OCaml Package Documentation\n\n- [demo](demo/index.md)\n' > rmd/index.md
  $ wodoc build --config doc/wodoc --src rsrc --md-src rmd --out p/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ test -e p/dev/index.md || echo "no package list"
  no package list
  $ grep -c 'Package Documentation' p/dev/llms.txt
  0
  [1]
  $ printf '(project demo)\n(title Demo)\n(url-prefix /demo)\n(odoc-driver "demo other")\n(packages demo)\n(landing demo/index.html)\n' > doc/wodoc
  $ wodoc build --config doc/wodoc --src rsrc --md-src rmd --out p2/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ test -e p2/dev/index.md || echo "no package list"
  no package list

In a manual-root project the landing's twin is deployed at that same
`index.md`, so the list could replace it, and the index summed the project up
with a list of packages:

  $ printf '(project demo)\n(title Demo)\n(url-prefix /demo)\n(packages demo)\n(manual-root)\n(landing demo/index.html)\n' > doc/wodoc
  $ wodoc build --config doc/wodoc --src rsrc --md-src rmd --out r/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ head -2 r/dev/index.md
  # Demo
  

  $ grep -c 'Package Documentation' r/dev/llms.txt
  0
  [1]
  $ sed -n '3s/^> //p' r/dev/llms.txt
  Welcome to the demo.
