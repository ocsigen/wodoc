A stanza wodoc does not read is an error, not silently ignored: a typo, or a
stanza left over from an older wodoc, would otherwise drop a setting with no
warning. The config is read before anything is built.

  $ mkdir doc
  $ build () { wodoc build --config doc/wodoc --out out/dev; }

An unknown top-level stanza names the file and lists the known ones:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (tilte Demo)
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (tilte ...) in the config: expected one of: project, title, url-prefix, menu-current, packages, landing, highlight, profile, odoc-driver, doc-manual, manual-files, sibling, nav, client-server, hosted, manual-root, mld-dir, mld-package, flat, static-copy, blog, markdown, css
  [1]

A retired stanza says what replaces it:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (pub /demo)
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (pub ...) in the config: it is now (url-prefix ...)
  [1]

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (manual-menu menu.wiki)
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (manual-menu ...) in the config: declare the left navigation with (nav ...)
  [1]

The blocks with named fields are checked too:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (client-server
  >   (server (lib demo.server) (indexdoc doc/server.indexdoc) (wraper Demo)))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (wraper ...) in (client-server (server ...)): expected one of: lib, indexdoc, heading, wrapper, skip
  [1]

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (blog (dir posts) (last 3))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (last ...) in (blog ...): expected one of: dir, out, heading, latest
  [1]

So is the left navigation, at the section level and inside a section (a
mistyped entry would otherwise vanish from the menu):

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (nav (sektion "Manual" (link "Home" index.html)))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (sektion ...) in (nav ...): expected one of: section, api-section
  [1]

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (nav (section "Manual" (link "Home" index.html) (lnk "Intro" intro.html)))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (lnk ...) in a (nav ...) section: expected one of: link, group
  [1]

The same holds for a standalone --nav file:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > CFG
  $ echo '(nav (section "Manual" (lnk "Intro" intro.html)))' > nav
  $ wodoc build --config doc/wodoc --nav nav --out out/dev
  wodoc: nav: unknown stanza (lnk ...) in a (nav ...) section: expected one of: link, group
  [1]
