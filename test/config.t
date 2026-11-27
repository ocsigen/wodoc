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
  wodoc: doc/wodoc: unknown stanza (tilte ...) in the config: expected one of: project, title, url-prefix, menu-current, packages, landing, highlight, profile, odoc-driver, doc-manual, manual-files, sibling, nav, variants, hosted, manual-root, mld-dir, mld-package, flat, static-copy, blog, markdown, llms, css
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

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (client-server (server (lib demo.server)))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (client-server ...) in the config: it is now (variants (variant <key> ...) ...)
  [1]

The blocks with named fields are checked too:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (variants
  >   (variant server (lib demo.server) (indexdoc doc/server.indexdoc) (wraper Demo)))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (wraper ...) in (variants (variant server ...)): expected one of: lib, indexdoc, heading, wrapper, skip, note
  [1]

A variant is named by its key, and only variants are expected there:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (variants (server (lib demo.server)))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (server ...) in (variants ...): expected one of: variant
  [1]
  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (variants (variant (lib demo.server)))
  > CFG
  $ build
  wodoc: doc/wodoc: (variants (variant ...)): expected a key first, e.g. (variant server (lib ...) ...)
  [1]

The hint for a retired stanza is given at the top level only, where the stanza
lived; inside a block, the same name is just unknown:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (variants (variant a (lib x) (pub /demo)))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (pub ...) in (variants (variant a ...)): expected one of: lib, indexdoc, heading, wrapper, skip, note
  [1]

The variants block is checked as a whole: it is declared once, lists at least
one variant, and names each variant once; a variant needs a library, takes one
atom per field, and has a lowercase key that does not clash with wodoc's own
classes ([wodoc-<key>] on the body, [wodoc-variant-<key>] on the switch):

  $ try () { printf '(project demo)\n%s\n' "$1" > doc/wodoc; build; }
  $ try '(variants)'
  wodoc: doc/wodoc: (variants ...) lists no (variant ...)
  [1]
  $ try '(variants (variant a (lib x))) (variants (variant b (lib y)))'
  wodoc: doc/wodoc: (variants ...) appears more than once
  [1]
  $ try '(variants (variant a (lib x)) (variant a (lib y)))'
  wodoc: doc/wodoc: (variants ...): a is declared twice
  [1]
  $ try '(variants (variant a (heading "A")))'
  wodoc: doc/wodoc: (variants (variant a ...)): missing (lib ...)
  [1]
  $ try '(variants (variant a (lib x y)))'
  wodoc: doc/wodoc: (variants (variant a ...)): (lib ...) takes one atom, once
  [1]
  $ try '(variants (variant a (lib x) stray))'
  wodoc: doc/wodoc: (variants (variant a ...)): unexpected stray
  [1]
  $ try '(variants stray (variant a (lib x)))'
  wodoc: doc/wodoc: (variants ...): unexpected stray
  [1]
  $ try '(variants (variant "a b" (lib x)))'
  wodoc: doc/wodoc: (variants (variant a b ...)): a key is a lowercase identifier, such as server
  [1]
  $ try '(variants (variant page (lib x)))'
  wodoc: doc/wodoc: (variants (variant page ...)): page is reserved for wodoc's own classes
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
  wodoc: doc/wodoc: unknown stanza (lnk ...) in a (nav ...) section: expected one of: link, group, page-tree
  [1]

The same holds for a standalone --nav file:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > CFG
  $ echo '(nav (section "Manual" (lnk "Intro" intro.html)))' > nav
  $ wodoc build --config doc/wodoc --nav nav --out out/dev
  wodoc: nav: unknown stanza (lnk ...) in a (nav ...) section: expected one of: link, group, page-tree
  [1]

The `(llms …)` stanza takes a title and a summary, nothing else:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (llms (title "Demo") (sumary "x"))
  > CFG
  $ build
  wodoc: doc/wodoc: unknown stanza (sumary ...) in (llms ...): expected one of: title, summary
  [1]

A value with spaces must be quoted, or all but its first word would be lost:

  $ cat > doc/wodoc <<'CFG'
  > (project demo)
  > (llms (title The Demo Project))
  > CFG
  $ build
  wodoc: doc/wodoc: (llms (title ...)) takes one string, given once: quote a value that holds spaces
  [1]

The same goes for a key given twice, a second stanza, or a stray word:

  $ printf '(project demo)\n(llms (title "A") (title "B"))\n' > doc/wodoc
  $ build
  wodoc: doc/wodoc: (llms (title ...)) takes one string, given once: quote a value that holds spaces
  [1]
  $ printf '(project demo)\n(llms (title "A"))\n(llms (summary "B"))\n' > doc/wodoc
  $ build
  wodoc: doc/wodoc: the config has more than one (llms ...) stanza
  [1]
  $ printf '(project demo)\n(llms oops (title "A"))\n' > doc/wodoc
  $ build
  wodoc: doc/wodoc: (llms ...) takes (title ...) and (summary ...) only
  [1]

`(odoc-driver …)` lists the packages to document, once; a nested list is an
error rather than a setting dropped in silence:

  $ printf '(project demo)\n(odoc-driver a (b))\n' > doc/wodoc
  $ build
  wodoc: doc/wodoc: (odoc-driver ...) takes the packages to document, once: (odoc-driver <pkg> ...)
  [1]
  $ printf '(project demo)\n(odoc-driver a)\n(odoc-driver b)\n' > doc/wodoc
  $ build
  wodoc: doc/wodoc: (odoc-driver ...) takes the packages to document, once: (odoc-driver <pkg> ...)
  [1]
  $ printf '(project demo)\n(odoc-driver)\n' > doc/wodoc
  $ build
  wodoc: doc/wodoc: (odoc-driver ...) takes the packages to document, once: (odoc-driver <pkg> ...)
  [1]
  $ printf '(project demo)\n(odoc-driver " ")\n' > doc/wodoc
  $ build
  wodoc: doc/wodoc: (odoc-driver ...) takes the packages to document, once: (odoc-driver <pkg> ...)
  [1]
