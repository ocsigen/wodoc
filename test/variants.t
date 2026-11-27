In a project with API variants (here the server and client sides of a library,
and a ppx), every API page starts with a notice naming its variant, with a
link to the same page in the other variant, or to that variant's index when
the module exists in one variant only. The manual pages carry no notice.

  $ mkdir -p doc
  $ for p in index:Demo intro:Introduction guide/index:Guide \
  >   demo.server.extra/Demo_extra/index:Demo_extra \
  >   demo.client.extra/Demo_extra/index:Demo_extra demo.ppx/index:demo.ppx \
  >   demo.server/index:demo.server demo.server/Demo/index:Demo \
  >   demo.server/Demo/Both/index:Both demo.server/Demo/Server_only/index:Server_only \
  >   demo.client/index:demo.client demo.client/Demo/index:Demo \
  >   demo.client/Demo/Both/index:Both demo.client/Demo/Client_only/index:Client_only; do
  >   mkdir -p "html/demo/$(dirname ${p%%:*})"
  >   printf '<html><body><header class="odoc-preamble"><h1>%s</h1></header><div class="odoc-content"><p>%s</p></div></body></html>' \
  >     "${p#*:}" "${p#*:}" > "html/demo/${p%%:*}.html"; done
  $ echo '<nav>Menu</nav>' > menu.html
  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (markdown false)
  > (landing index.html)
  > (variants
  >   (variant server (lib demo.server) (indexdoc none) (heading "Server API") (wrapper Demo))
  >   (variant client (lib demo.client) (indexdoc none) (heading "Client API") (wrapper Demo)
  >     (note "This code runs in the browser & is compiled to JavaScript."))
  >   (variant ppx (lib demo.ppx) (indexdoc none) (heading "PPX")))
  > CFG
  $ wodoc build --config doc/wodoc --src html/demo --out out/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ notice () {
  >   sed -n '/<div class="wodoc-variant-notice/,/<\/div>/p' "out/dev/$1" | sed 's/^ *//'
  > }

A module of both variants links to its counterpart; the variant's note is escaped:

  $ notice demo.client/Demo/Both/index.html
  <div class="wodoc-variant-notice wodoc-variant-notice-client" role="note">
  <p>You are reading the <strong>Client API</strong> documentation. This code runs in the browser &amp; is compiled to JavaScript.</p>
  <p><a href="../../../demo.server/Demo/Both/index.html">See this page in the Server API</a>.</p>
  </div>
  $ notice demo.server/Demo/Both/index.html
  <div class="wodoc-variant-notice wodoc-variant-notice-server" role="note">
  <p>You are reading the <strong>Server API</strong> documentation.</p>
  <p><a href="../../../demo.client/Demo/Both/index.html">See this page in the Client API</a>.</p>
  </div>

A module of one variant only links to the other variant's index:

  $ notice demo.client/Demo/Client_only/index.html
  <div class="wodoc-variant-notice wodoc-variant-notice-client" role="note">
  <p>You are reading the <strong>Client API</strong> documentation. This code runs in the browser &amp; is compiled to JavaScript.</p>
  <p>This page has no equivalent in the <a href="../../../demo.server/Demo/index.html">Server API</a>.</p>
  </div>
  $ notice demo.server/Demo/Server_only/index.html | grep equivalent
  <p>This page has no equivalent in the <a href="../../../demo.client/Demo/index.html">Client API</a>.</p>

The library index pages are counterparts too:

  $ notice demo.server/index.html | grep href
  <p><a href="../demo.client/index.html">See this page in the Client API</a>.</p>

So are the pages of a sub-library:

  $ notice demo.client.extra/Demo_extra/index.html | grep href
  <p><a href="../../demo.server.extra/Demo_extra/index.html">See this page in the Server API</a>.</p>

A variant under another wrapper module (here a ppx, with none) has no counterpart
modules: its pages link nowhere, and no page links to it:

  $ notice demo.ppx/index.html
  <div class="wodoc-variant-notice wodoc-variant-notice-ppx" role="note">
  <p>You are reading the <strong>PPX</strong> documentation.</p>
  </div>
  $ grep -l 'in the <a[^>]*>PPX\|in the PPX' -r out/dev
  [1]

A manual page has no notice, even in a subdirectory, and no leftover hole:

  $ grep -c 'wodoc-variant-notice\|{{banner}}' out/dev/intro.html out/dev/guide/index.html
  out/dev/intro.html:0
  out/dev/guide/index.html:0
  [1]

Nor has a page of a project without variants:

  $ sed -i.bak '/variants/,$d' doc/wodoc
  $ wodoc build --config doc/wodoc --src html/demo --out out2/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ grep -c 'wodoc-variant-notice\|{{banner}}' out2/dev/demo.client/Demo/Both/index.html
  0
  [1]
