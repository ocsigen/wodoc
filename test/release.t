`wodoc release` freezes the CI-built dev/ as a stable version and repoints the
`latest` symlink at it — the per-project release procedure (the CI only ever
rebuilds dev/).

  $ mkdir -p site/dev/Mod
  $ echo '<html>dev landing</html>' > site/dev/index.html
  $ echo '<html>a module</html>' > site/dev/Mod/index.html

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

A second release adds another version and moves `latest`; older versions stay:

  $ wodoc release --site site --version 2.0.0
  wodoc release: froze dev -> 2.0.0, latest -> 2.0.0
  $ readlink site/latest
  2.0.0
  $ test -d site/1.0.0 && echo "1.0.0 preserved"
  1.0.0 preserved
