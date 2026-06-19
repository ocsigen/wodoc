`wodoc release` freezes the CI-built dev/ as a stable version and repoints the
`latest` symlink at it — the per-project release procedure (the CI only ever
rebuilds dev/).

  $ mkdir -p site/dev/Mod
  $ echo '<html>dev landing</html>' > site/dev/index.html
  $ echo '<html>a module</html>' > site/dev/Mod/index.html
  $ touch site/dev/wodoc-highlight.js

(every wodoc build ships wodoc-highlight.js; it is the marker that tells a
version dir from a stray source/asset dir, so the copies inherit it.)

  $ wodoc release --site site --version 1.0.0
  wodoc release: froze dev -> 1.0.0, latest -> 1.0.0

The version is a full copy of dev/, `latest` points at it, and a project-root
redirect to latest/ is written:

  $ cat site/1.0.0/Mod/index.html
  <html>a module</html>
  $ readlink site/latest
  1.0.0
  $ grep -o 'url=[^"]*' site/index.html
  url=latest/index.html

The version manifest read by the page selector lists dev first, then the
versions newest-first, and records which one `latest` points at:

  $ cat site/versions.json
  {"latest":"1.0.0","list":["dev","1.0.0"]}

A second release adds another version and moves `latest`; older versions stay
and the manifest is refreshed (the only file a release rewrites):

  $ wodoc release --site site --version 2.0.0
  wodoc release: froze dev -> 2.0.0, latest -> 2.0.0
  $ readlink site/latest
  2.0.0
  $ test -d site/1.0.0 && echo "1.0.0 preserved"
  1.0.0 preserved
  $ cat site/versions.json
  {"latest":"2.0.0","list":["dev","2.0.0","1.0.0"]}

Versions are ordered numerically, not alphabetically (10.0.0 > 2.0.0):

  $ wodoc release --site site --version 10.0.0
  wodoc release: froze dev -> 10.0.0, latest -> 10.0.0
  $ cat site/versions.json
  {"latest":"10.0.0","list":["dev","10.0.0","2.0.0","1.0.0"]}

A stale project-root redirect left by an older doc setup (e.g. lwt carried a
`latest/manual/manual` leftover on gh-pages) is OVERWRITTEN, not preserved:

  $ printf '<meta http-equiv="refresh" content="0; url=latest/manual/manual"/>\n' > site/index.html
  $ wodoc release --site site --version 10.0.1
  wodoc release: froze dev -> 10.0.1, latest -> 10.0.1
  $ grep -o 'url=[^"]*' site/index.html
  url=latest/index.html
