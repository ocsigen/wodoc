A build reports the markup that was meant to become a link or an image and did
not: a dead reference, or a wikicréole image the wiki conversion left behind
(odoc has no image syntax, so `{{file.png|alt}}` survives as literal text).
`--strict-refs` turns those reports into a build failure, which is what a doc CI
wants.

References into a dependency the site does not host (`Stdlib`, `Ppxlib`) are
counted apart: they are expected, and no change here can repair them.

  $ mkdir -p doc/manual
  $ cat > doc/manual/intro.mld <<'XEOF'
  > {0 Intro}
  > Read {!page-"details"} next.
  > XEOF
  $ cat > doc/manual/details.mld <<'XEOF'
  > {0 Details}
  > Back to {!page-"intro"}; see also {{!page-"gone"}the missing page}
  > and {{!Stdlib.List}the standard library}.
  > {{files/shot.png|a screenshot}}
  > XEOF
  $ cat > doc/wodoc <<'XEOF'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (mld-package demo)
  > (flat)
  > XEOF

A reference with no label degrades to a bare `<code>`, indistinguishable from
inline code, so only the labelled shape can be reported.

  $ wodoc build --config doc/wodoc --out site/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null 2>&1 | grep '^wodoc:'
  wodoc: details.html: leftover wikicréole image: {files/shot.png|a screenshot
  wodoc: 1 leftover wikicréole image in 1 page (--strict-refs makes this fatal)
  wodoc: details.html: unresolved reference: gone
  wodoc: 1 unresolved reference in 1 page (--strict-refs makes this fatal)
  wodoc: 1 reference into a dependency this site does not host in 1 page

Mutual references resolve: `odoc link` is run over every compiled page, not one
page at a time, which would leave each reference to a not-yet-compiled page dead
(alphabetically forward ones, i.e. most of them in a fresh build).

  $ grep -c 'href="details.html"' site/dev/intro.html
  1
  $ grep -c 'href="intro.html"' site/dev/details.html
  1

A lowercase reference is a page or section of the project when it sits on a manual
page. On an API page (one under a module directory, i.e. a path segment starting
with a capital, which a capitalised page name stands in for here) it names a
value or type of a signature odoc could not reach instead (what the standard
library's functors document: `key`, `elt` in an applied `Map.Make`), and only
counts when it names a manual page of this build:

  $ cat > doc/manual/Api.mld <<'XEOF'
  > {0 Api}
  > Keyed by {{!key}the key type} of the applied map, and see
  > {{!page-"details".nowhere}a section of details}.
  > XEOF
  $ rm -rf _wodoc-html site
  $ wodoc build --config doc/wodoc --out site/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null 2>&1 | grep 'unresolved reference'
  wodoc: Api.html: unresolved reference: details.nowhere
  wodoc: details.html: unresolved reference: gone
  wodoc: 2 unresolved references in 2 pages (--strict-refs makes this fatal)

`key` is left out of that count: nothing in this build is named `key`, so it is a
signature odoc could not reach, not a page of ours. `details.nowhere` is in it:
`details` is one of this build's pages, so the reference is ours and its anchor
leads nowhere.

  $ rm doc/manual/Api.mld

The build fails under `--strict-refs`, naming what to fix, and never over a
dependency it cannot reach:

  $ rm -rf _wodoc-html site
  $ wodoc build --config doc/wodoc --out site/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null --strict-refs 2> log
  [1]
  $ grep '^wodoc:' log
  wodoc: details.html: leftover wikicréole image: {files/shot.png|a screenshot
  wodoc: 1 leftover wikicréole image in 1 page
