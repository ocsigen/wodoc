A (page-tree) nav entry is the manual tree odoc 3 builds from the manual's
directories (odoc-pages/<dir>/, ordered by @children_order), read from the
sidebar.json odoc_driver writes next to the package's pages, so the left
column follows the same tree as ocaml.org. The sidebar below has odoc's shape
for a package whose manual has a page named with a capital (FAQ), a clickable
directory (sub/), a directory with @toc_status hidden (other/, not a link), a
library and its sources. Its links are relative to odoc's HTML root (html/),
its labels are HTML.

  $ mkdir -p html/demo/sub html/demo/other html/demo/demo/Demo html/demo/src doc
  $ cat > html/demo/sidebar.json <<'JSON'
  > [{"node":{"url":"demo/index.html","kind":"leaf-page","content":"Demo"},"children":[
  >   {"node":{"url":"demo/intro.html","kind":"leaf-page","content":"Introduction"},"children":[]},
  >   {"node":{"url":"demo/FAQ.html","kind":"leaf-page","content":"FAQ"},"children":[]},
  >   {"node":{"url":"demo/sub/index.html","kind":"leaf-page","content":"Sub group"},"children":[
  >     {"node":{"url":"demo/sub/alpha.html","kind":"leaf-page","content":"Alpha &amp; co"},"children":[]},
  >     {"node":{"url":"demo/sub/beta.html","kind":"leaf-page","content":"The <code>Beta</code>\n caf&#233;"},"children":[]}]},
  >   {"node":{"url":null,"kind":null,"content":"Other group"},"children":[
  >     {"node":{"url":"demo/other/services.html","kind":"leaf-page","content":"Other services"},"children":[]}]},
  >   {"node":{"url":null,"kind":null,"content":"Library <code>demo</code>"},"children":[
  >     {"node":{"url":"demo/demo/Demo/index.html","kind":"module","content":"Demo"},"children":[]}]},
  >   {"node":{"url":"demo/src/index.html","kind":"leaf-page","content":"Sources"},"children":[
  >     {"node":{"url":null,"kind":null,"content":"demo"},"children":[
  >       {"node":{"url":"demo/src/demo/demo.ml.html","kind":"source","content":"demo.ml"},"children":[]}]}]}]}]
  > JSON
  $ cat > menu.html <<'HTML'
  > <nav>Menu</nav>
  > HTML
  $ for p in index:Demo intro:Introduction FAQ:FAQ sub/index:'Sub group' \
  >   sub/alpha:Alpha sub/beta:Beta other/index:'Other group' \
  >   other/services:'Other services' demo/Demo/index:Demo src/index:Sources; do
  >   printf '<html><body><header class="odoc-preamble"><h1>%s</h1></header><div class="odoc-content"><p>%s</p></div></body></html>' \
  >     "${p#*:}" "${p#*:}" > "html/demo/${p%%:*}.html"; done

Without a (nav ...) stanza, the left column is the manual tree, in a section
named after the project. The tree starts with its index page; the hidden
directory is a heading without a link; the library and the sources are left
out:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (odoc-driver demo)
  > (markdown false)
  > (landing index.html)
  > CFG
  $ wodoc build --config doc/wodoc --src html/demo --out out/dev \
  >   --menu menu.html --label dev
  $ sed -n '/manual-nav/,/<\/nav>/p' out/dev/intro.html
  <nav class="api-nav manual-nav">
  <h3>Demo</h3>
  <ul class="api-section">
  <li class="ml3" data-wodoc-page="index.html"><a href="./index.html">Demo</a></li>
  <li class="ml3 current" data-wodoc-page="intro.html"><a href="./intro.html">Introduction</a></li>
  <li class="ml3" data-wodoc-page="FAQ.html"><a href="./FAQ.html">FAQ</a></li>
  </ul>
  <h4 class="ml3" data-wodoc-page="sub/index.html"><a href="./sub/index.html">Sub group</a></h4>
  <ul class="api-section">
  <li class="ml4" data-wodoc-page="sub/alpha.html"><a href="./sub/alpha.html">Alpha &amp; co</a></li>
  <li class="ml4" data-wodoc-page="sub/beta.html"><a href="./sub/beta.html">The Beta café</a></li>
  </ul>
  <h4 class="ml3">Other group</h4>
  <ul class="api-section">
  <li class="ml4" data-wodoc-page="other/services.html"><a href="./other/services.html">Other services</a></li>
  </ul>
  </nav>

A page in a directory is marked current and links back up the tree:

  $ grep -o '<li class="ml4 current"[^>]*><a href="[^"]*"' out/dev/sub/alpha.html
  <li class="ml4 current" data-wodoc-page="sub/alpha.html"><a href="../sub/alpha.html"
  $ grep -o '<h4 class="ml3 current"[^>]*>' out/dev/sub/index.html
  <h4 class="ml3 current" data-wodoc-page="sub/index.html">

A page tree can start below the index page, at a directory, even one that
odoc does not link: its pages come without the directory's own entry.

  $ cat >> doc/wodoc <<'CFG'
  > (nav
  >   (section "Manual"
  >     (page-tree other/index.html)))
  > CFG
  $ wodoc build --config doc/wodoc --src html/demo --out out2/dev \
  >   --menu menu.html --label dev
  $ sed -n '/manual-nav/,/<\/nav>/p' out2/dev/intro.html
  <nav class="api-nav manual-nav">
  <h3>Manual</h3>
  <ul class="api-section">
  <li class="ml3" data-wodoc-page="other/services.html"><a href="./other/services.html">Other services</a></li>
  </ul>
  </nav>

A page listed twice in the left column (here by hand and by the tree) is
highlighted twice on its own pages: wodoc warns.

  $ sed -i.bak 's|(page-tree other/index.html)|(link "Overview" index.html) (page-tree)|' doc/wodoc
  $ wodoc build --config doc/wodoc --src html/demo --out out3/dev \
  >   --menu menu.html --label dev
  wodoc: warning: index.html is listed more than once in the left navigation

An empty --nav file is an empty nav, not the default one:

  $ : > empty
  $ wodoc build --config doc/wodoc --src html/demo --out out4/dev \
  >   --menu menu.html --label dev --nav empty
  $ grep -c manual-nav out4/dev/intro.html
  0
  [1]

In a client/server project, a page in a directory of the tree is highlighted
too: its directory is not taken for one of the API libraries.

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (markdown false)
  > (landing index.html)
  > (client-server
  >   (server (lib demo.server) (indexdoc none) (heading "Server API") (wrapper Demo))
  >   (client (lib demo.client) (indexdoc none) (heading "Client API") (wrapper Demo)))
  > CFG
  $ wodoc build --config doc/wodoc --src html/demo --out out5/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ grep -o '<li class="ml4 current"[^>]*>' out5/dev/sub/alpha.html
  <li class="ml4 current" data-wodoc-page="sub/alpha.html">

When the pages of several packages are assembled from odoc's HTML root, the
sidebar.json is found in the package's directory, and the links stay relative
to the root:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (odoc-driver demo)
  > (packages demo)
  > (markdown false)
  > (landing demo/index.html)
  > (nav
  >   (section "Manual"
  >     (page-tree demo/sub/index.html)))
  > CFG
  $ wodoc build --config doc/wodoc --src html --out out6/dev \
  >   --menu menu.html --label dev
  $ sed -n '/manual-nav/,/<\/nav>/p' out6/dev/demo/intro.html
  <nav class="api-nav manual-nav">
  <h3>Manual</h3>
  <ul class="api-section">
  <li class="ml3" data-wodoc-page="demo/sub/index.html"><a href="../demo/sub/index.html">Sub group</a></li>
  <li class="ml3" data-wodoc-page="demo/sub/alpha.html"><a href="../demo/sub/alpha.html">Alpha &amp; co</a></li>
  <li class="ml3" data-wodoc-page="demo/sub/beta.html"><a href="../demo/sub/beta.html">The Beta café</a></li>
  </ul>
  </nav>

A page tree that cannot be read is an error, not an empty menu: no
sidebar.json (a build without odoc_driver), a page the sidebar does not show,
a malformed sidebar.json.

  $ build () {
  >   sed -i.bak "s|(page-tree[^)]*)|(page-tree $1)|" doc/wodoc
  >   wodoc build --config doc/wodoc --src html --out out7/dev \
  >     --menu menu.html --label dev
  > }
  $ build index.html
  wodoc: (page-tree index.html): no sidebar.json in html (odoc_driver writes one for each package)
  [1]
  $ build demo/nowhere.html
  wodoc: (page-tree demo/nowhere.html): html/demo/sidebar.json does not show demo/nowhere.html
  [1]
  $ echo '[{"node":{}}]' > html/demo/sidebar.json
  $ build demo/index.html
  wodoc: (page-tree demo/index.html): html/demo/sidebar.json: unexpected contents: Expected array, got null
  [1]
