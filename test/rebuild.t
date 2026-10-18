A build starts from empty work trees: a page removed or renamed since the
previous build must not survive in odoc's output, where it would be assembled
and published with the site (and listed in odoc's sidebar).

  $ mkdir -p doc/manual
  $ cat > doc/manual/intro.mld <<'XEOF'
  > {0 Intro}
  > XEOF
  $ cat > doc/manual/old.mld <<'XEOF'
  > {0 Old}
  > XEOF
  $ cat > doc/wodoc <<'XEOF'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (mld-package demo)
  > (markdown false)
  > XEOF
  $ build () {
  >   wodoc build --config doc/wodoc --out "$1" --label dev \
  >     --mld-dir doc/manual --nav /dev/null 2>/dev/null
  > }

  $ build site1/dev
  $ ls site1/dev/*.html
  site1/dev/intro.html
  site1/dev/old.html

The page is renamed; the next build has the new page only:

  $ mv doc/manual/old.mld doc/manual/new.mld
  $ build site2/dev
  $ ls site2/dev/*.html
  site2/dev/intro.html
  site2/dev/new.html
