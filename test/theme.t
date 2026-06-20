`wodoc build` is self-contained by default: with no (css ...) and no --menu it
ships a built-in theme (wodoc.css) and a default top bar, all linked by
per-version RELATIVE paths, so the site works at any deploy path. (css ...) and
--menu override those. This test feeds a canned odoc HTML tree (--src) so it
checks wodoc's own template/asset placement without invoking odoc.

  $ mkdir -p src/demo/Mod doc
  $ cat > doc/wodoc <<'EOF'
  > (project demo)
  > (title Demo)
  > (pub /demo)
  > (packages demo)
  > (landing demo/index.html)
  > (nav (section "Manual" (link "Introduction" "demo/index.html")))
  > EOF
  $ canned () {
  >   printf '<html><body><header class="odoc-preamble"><h1>%s</h1></header><div class="odoc-content"><p>%s</p></div></body></html>' "$1" "$2"
  > }
  $ canned "Demo" "Welcome." > src/demo/index.html
  $ canned "Mod" "A module." > src/demo/Mod/index.html

Build with neither --menu nor (css ...):

  $ wodoc build --config doc/wodoc --src src --out out/dev --label dev 2>/dev/null

The built-in theme is shipped at the version root:

  $ test -f out/dev/wodoc.css && echo ok
  ok

A page links the theme and the highlighter by relative path (here base is ..):

  $ grep -o '<link rel="stylesheet" href="[^"]*"' out/dev/demo/index.html
  <link rel="stylesheet" href="../wodoc.css"
  $ grep -o '<script src="[^"]*wodoc-highlight[^"]*"' out/dev/demo/index.html
  <script src="../wodoc-highlight.js"

The default top bar carries the project title (no --menu given):

  $ grep -o '<header class="wodoc-header"><p class="logo-subproject">[^<]*' out/dev/demo/index.html
  <header class="wodoc-header"><p class="logo-subproject">Demo

With (css ...) and --menu, those override the defaults: a relative href is
copied into the build and linked relatively, an absolute one is left verbatim,
the built-in theme is not shipped, and the given menu replaces the default bar.

  $ cat >> doc/wodoc <<'EOF'
  > (css theme.css /shared/site.css)
  > EOF
  $ echo '/* custom */' > doc/theme.css
  $ printf '<nav class="custom-menu">%s</nav>' '{{subproject}}' > menu.html
  $ wodoc build --config doc/wodoc --src src --out out2/dev --label dev --menu menu.html 2>/dev/null
  $ test -f out2/dev/theme.css && echo "relative css shipped"
  relative css shipped
  $ test -f out2/dev/wodoc.css || echo "no built-in theme when (css) is set"
  no built-in theme when (css) is set
  $ grep -o '<link rel="stylesheet" href="[^"]*"' out2/dev/demo/index.html
  <link rel="stylesheet" href="../theme.css"
  <link rel="stylesheet" href="/shared/site.css"
  $ grep -c 'wodoc-header' out2/dev/demo/index.html
  0
  [1]
  $ grep -o '<nav class="custom-menu">' out2/dev/demo/index.html
  <nav class="custom-menu">
