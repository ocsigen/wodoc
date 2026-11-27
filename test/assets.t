In a direct-mld build, the files under `<mld-dir>/files` are odoc assets of the
pages, as they are for the pages of a package rendered by odoc_driver (ocaml.org).
An image reference resolves, and the same source reads right on both sites.

  $ mkdir -p doc/manual/files/sub
  $ printf 'png' > doc/manual/files/shot.png
  $ printf 'svg' > doc/manual/files/sub/diagram.svg
  $ cat > doc/manual/intro.mld <<'XEOF'
  > {0 Intro}
  > {{image!files/shot.png}A screenshot}
  > 
  > {image!files/sub/diagram.svg}
  > XEOF
  $ cat > doc/wodoc <<'XEOF'
  > (project demo)
  > (title Demo)
  > (url-prefix /demo)
  > (markdown false)
  > (flat)
  > XEOF

With no `(mld-package …)`, the parent id of the pages is the project. Both
references resolve, so the build passes `--strict-refs`:

  $ wodoc build --config doc/wodoc --out site/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null --strict-refs 2>/dev/null

odoc renders each image as a link to the file, with its label as alternative
text (the file name when there is none):

  $ grep -o '<a href="[^"]*" class="img-link"><img [^>]*>' site/dev/intro.html
  <a href="files/shot.png" class="img-link"><img src="files/shot.png" alt="A screenshot"/>
  <a href="files/sub/diagram.svg" class="img-link"><img src="files/sub/diagram.svg" alt="diagram.svg"/>

and the files are published next to the pages:

  $ cat site/dev/files/shot.png site/dev/files/sub/diagram.svg
  pngsvg

What the walk cannot use does not stop the build: a dangling link is skipped
with a warning, a link back up the tree is walked once, and a file whose name
starts with a dash is still an asset, not an option of odoc.

  $ ln -s nowhere.png doc/manual/files/dangling.png
  $ ln -s .. doc/manual/files/sub/up
  $ printf 'dash' > doc/manual/files/-x.png
  $ wodoc build --config doc/wodoc --out site2/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null --strict-refs 2>&1 | grep 'skipping'
  wodoc: skipping doc/manual/files/dangling.png: No such file or directory

A [files] that is not a directory has no assets:

  $ rm -r doc/manual/files
  $ printf 'not a directory' > doc/manual/files
  $ cat > doc/manual/intro.mld <<'XEOF'
  > {0 Intro}
  > XEOF
  $ wodoc build --config doc/wodoc --out site3/dev --label dev \
  >   --mld-dir doc/manual --nav /dev/null --strict-refs 2>/dev/null
