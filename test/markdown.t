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

A project can opt out of the whole Markdown pipeline with (markdown false): no
.md twins, no llms.txt, and no <link rel="alternate"> on the pages.

  $ printf '(project demo)\n(title Demo)\n(url-prefix /demo)\n(packages demo)\n(landing demo/index.html)\n(markdown false)\n' > doc/wodoc
  $ wodoc build --config doc/wodoc --src src --md-src md --out off/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ test -e off/dev/demo/index.md && echo twin || echo "no twin"
  no twin
  $ test -e off/dev/llms.txt && echo index || echo "no index"
  no index
  $ grep -c 'rel="alternate"' off/dev/demo/index.html
  0
  [1]
