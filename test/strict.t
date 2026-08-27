A build reports the markup that was meant to become a link or an image and did
not: a dead reference, or a wikicréole image the wiki conversion left behind
(odoc has no image syntax, so `{{file.png|alt}}` survives as literal text).
`--strict-refs` turns those reports into a build failure, which is what a doc CI
wants.

Two pages that reference each other, plus a labelled reference to a module
nothing here provides and a leftover image. (A reference with no label degrades
to a bare `<code>` instead of a span, indistinguishable from inline code, so only
the labelled shape can be reported.)

  $ mkdir -p doc/manual
  $ cat > doc/manual/intro.mld <<'XEOF'
  > {0 Intro}
  > Read {!page-"details"} next.
  > XEOF
  $ cat > doc/manual/details.mld <<'XEOF'
  > {0 Details}
  > Back to {!page-"intro"}, built on {{!Elsewhere.Thing}the thing}.
  > {{files/shot.png|a screenshot}}
  > XEOF
  $ cat > doc/wodoc <<'XEOF'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (mld-package demo)
  > (flat)
  > XEOF

  $ wodoc build --config doc/wodoc --out site/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null 2>&1 | grep '^wodoc:'
  wodoc: details.html: leftover wikicréole image: {files/shot.png|a screenshot
  wodoc: 1 leftover wikicréole image in 1 page (--strict-refs makes this fatal)
  wodoc: details.html: unresolved reference: Elsewhere.Thing
  wodoc: 1 unresolved reference in 1 page (--strict-refs makes this fatal)

Mutual references resolve: `odoc link` is run over every compiled page, not one
page at a time, which would leave each reference to a not-yet-compiled page dead
(alphabetically forward ones, i.e. most of them in a fresh build).

  $ grep -c 'href="details.html"' site/dev/intro.html
  1
  $ grep -c 'href="intro.html"' site/dev/details.html
  1

The same build fails under `--strict-refs`, naming what to fix:

  $ rm -rf _wodoc-html site
  $ wodoc build --config doc/wodoc --out site/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null --strict-refs 2> log
  [1]
  $ grep '^wodoc:' log
  wodoc: details.html: leftover wikicréole image: {files/shot.png|a screenshot
  wodoc: 1 leftover wikicréole image in 1 page
