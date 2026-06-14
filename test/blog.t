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
  > (blog (dir doc/blog) (out blog) (heading Blog) (latest 5))
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
