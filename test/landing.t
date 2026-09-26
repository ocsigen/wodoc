The version root index.html of a build is the landing page. In a single-package
odoc-driver build, the source tree is the package's own subtree, whose root
index.html is the package's index.mld: with (landing index.html) it is the real
home page, assembled like the other pages, and no redirect replaces it (a
redirect to itself would loop).

  $ mkdir -p src/Mod doc
  $ cat > menu.html <<'HTML'
  > <nav>{{subproject}}{{leftnav}}</nav>
  > HTML
  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (odoc-driver demo)
  > (markdown false)
  > (landing index.html)
  > (nav
  >   (section "Manual"
  >     (link "Overview" index.html index)
  >     (link "Introduction" intro.html intro)))
  > CFG
  $ canned () {
  >   printf '<html><body><header class="odoc-preamble"><h1>%s</h1></header><div class="odoc-content"><p>%s</p></div></body></html>' "$1" "$2"
  > }
  $ canned "Demo" "Welcome to the demo." > src/index.html
  $ canned "Introduction" "Getting started." > src/intro.html
  $ canned "Mod" "A module." > src/Mod/index.html

  $ wodoc build --config doc/wodoc --src src --out out/dev \
  >   --menu menu.html --label dev 2>/dev/null

  $ grep -c 'http-equiv="refresh"' out/dev/index.html
  0
  [1]
  $ grep -o 'Welcome to the demo.' out/dev/index.html
  Welcome to the demo.

A landing elsewhere still gets the version root redirect:

  $ sed -i.bak 's/(landing index.html)/(landing intro.html)/' doc/wodoc
  $ wodoc build --config doc/wodoc --src src --out out2/dev \
  >   --menu menu.html --label dev 2>/dev/null
  $ grep -o 'url=[^"]*' out2/dev/index.html
  url=intro.html
