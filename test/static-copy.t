`(static-copy <src> [<dest>])` copies a file or a directory verbatim into the
output. The destination is replaced on every build, so a rebuild in the same
output does not nest the copy inside the previous one.

  $ mkdir -p src doc snapshot
  $ cat > menu.html <<'HTML'
  > <nav>{{subproject}}{{leftnav}}</nav>
  > HTML
  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (odoc-driver demo)
  > (markdown false)
  > (landing index.html)
  > (static-copy snapshot api)
  > CFG
  $ printf '<html><body><header class="odoc-preamble"><h1>Demo</h1></header><div class="odoc-content"><p>Hi.</p></div></body></html>' > src/index.html
  $ echo 'old API' > snapshot/Mod.html
  $ build () {
  >   wodoc build --config doc/wodoc --src src --out out/dev --menu menu.html \
  >     --label dev 2>/dev/null
  > }
  $ build
  $ build
  $ find out/dev/api | sort
  out/dev/api
  out/dev/api/Mod.html

A file removed from the source is gone from the copy too:

  $ echo 'new API' > snapshot/New.html
  $ unlink snapshot/Mod.html
  $ build
  $ find out/dev/api | sort
  out/dev/api
  out/dev/api/New.html

The destination must stay strictly inside the version directory, since it is
replaced:

  $ for d in . .. ../x a/../b /abs api/; do
  >   printf '(project demo)\n(static-copy snapshot %s)\n' "$d" > doc/wodoc
  >   wodoc build --config doc/wodoc --src src --out out/dev --menu menu.html
  > done
  wodoc: doc/wodoc: bad (static-copy ...) destination ".": expected a relative path inside the version directory, with no . or .. segment
  wodoc: doc/wodoc: bad (static-copy ...) destination "..": expected a relative path inside the version directory, with no . or .. segment
  wodoc: doc/wodoc: bad (static-copy ...) destination "../x": expected a relative path inside the version directory, with no . or .. segment
  wodoc: doc/wodoc: bad (static-copy ...) destination "a/../b": expected a relative path inside the version directory, with no . or .. segment
  wodoc: doc/wodoc: bad (static-copy ...) destination "/abs": expected a relative path inside the version directory, with no . or .. segment
  wodoc: doc/wodoc: bad (static-copy ...) destination "api/": expected a relative path inside the version directory, with no . or .. segment
  [1]
