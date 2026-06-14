A wodoc blog is a directory of dated `.mld` posts (named `YYYY-MM-DD-slug.mld`).
wodoc builds them like any page, auto-lists them newest-first in a generated
left-nav section, and expands the landing's `{%wodoc:blog-latest%}` marker (here
written in its build-path-agnostic `{%html:<!--wodoc-blog-latest-->%}` form) into
a styled "latest posts" list. The publication date comes from the file name, the
author from odoc's `@author`, the title from the heading and the excerpt from the
first body paragraph.

  $ mkdir -p doc/blog
  $ cat > doc/blog/2026-06-10-hello.mld <<'XEOF'
  > {0 Hello world}
  > 
  > @author Alice
  > 
  > The first post's opening paragraph, which becomes the excerpt.
  > XEOF
  $ cat > doc/blog/2026-06-14-second.mld <<'XEOF'
  > {0 The second post}
  > 
  > @author Bob
  > 
  > A later post, so it sorts above the first one.
  > XEOF
  $ cat > doc/index.mld <<'XEOF'
  > {0 Home}
  > 
  > {%html:<!--wodoc-blog-latest-->%}
  > XEOF
  $ cat > doc/wodoc <<'XEOF'
  > (project demo)
  > (blog (dir blog) (out blog) (heading Blog) (latest 5))
  > (nav (section Manual (link Home index.html index)))
  > XEOF
  $ echo '<header>menu</header>' > menu.html
  $ wodoc build --config doc/wodoc --out _site/dev --label dev --menu menu.html --mld-dir doc 2>/dev/null

Each post becomes its own page, deployed under the configured `(out blog)`:

  $ ls _site/dev/blog
  hello.html
  second.html

The left nav lists the posts newest-first, labelled "date — title":

  $ grep -o '<a href="[^"]*blog/[^"]*">[^<]*</a>' _site/dev/index.html
  <a href="./blog/second.html">2026-06-14 — The second post</a>
  <a href="./blog/hello.html">2026-06-10 — Hello world</a>

The landing's marker expands to the styled list of recent posts (title, date —
author, excerpt), newest first:

  $ grep -o 'wodoc-blog-title" href="[^"]*">[^<]*' _site/dev/index.html
  wodoc-blog-title" href="./blog/second.html">The second post
  wodoc-blog-title" href="./blog/hello.html">Hello world
  $ grep -o 'wodoc-blog-meta">[^<]*' _site/dev/index.html
  wodoc-blog-meta">2026-06-14 — Bob
  wodoc-blog-meta">2026-06-10 — Alice
  $ grep -o 'wodoc-blog-excerpt">[^<]*' _site/dev/index.html
  wodoc-blog-excerpt">A later post, so it sorts above the first one.
  wodoc-blog-excerpt">The first post&#x27;s opening paragraph, which becomes the excerpt.

A post page carries the site chrome and highlights its own nav entry:

  $ grep -c 'class="ml3 current"[^>]*data-wodoc-page="blog/second.html"' _site/dev/blog/second.html
  1

A page built through the low-level `assemble` path (e.g. a site home, not
`wodoc build`) can still carry the listing: `--blog-config` expands the marker
with the blog's latest-posts fragment, `--blog-base` giving the relative path
from this page to the blog root.

  $ cat > home-odoc.html <<'XEOF'
  > <header class="odoc-preamble"><h1 id="home">Home</h1></header>
  > <div class="odoc-content"><p><!--wodoc-blog-latest--></p></div>
  > XEOF
  $ printf '<html><body>{{preamble}}{{content}}</body></html>' > tmpl.html
  $ wodoc assemble --template tmpl.html --blog-config doc/wodoc home-odoc.html | grep -o 'wodoc-blog-title" href="[^"]*"'
  wodoc-blog-title" href="blog/second.html"
  wodoc-blog-title" href="blog/hello.html"

`wodoc blog-nav` prints the blog's left-nav block (for the low-level assemble
path), one entry per post, newest first:

  $ wodoc blog-nav --config doc/wodoc --base . | grep -o 'data-wodoc-page="[^"]*"'
  data-wodoc-page="blog/second.html"
  data-wodoc-page="blog/hello.html"

`wodoc blog-feed` prints an Atom feed for syndication (e.g. OCaml Planet): a
self link at the chosen feed path, and one entry per post with an absolute URL
(base-url + blog-path + post path) and the excerpt as a summary.

  $ wodoc blog-feed --config doc/wodoc --base-url https://ocsigen.org \
  >   --blog-path /blog --title "Ocsigen Blog" --author "Ocsigen Project" \
  >   | grep -o '<link href="[^"]*" rel="self" />\|<title>[^<]*</title>\|<link href="https://ocsigen.org/blog/[^"]*"'
  <title>Ocsigen Blog</title>
  <link href="https://ocsigen.org/feed.xml" rel="self" />
  <title>The second post</title>
  <link href="https://ocsigen.org/blog/blog/second.html"
  <title>Hello world</title>
  <link href="https://ocsigen.org/blog/blog/hello.html"
