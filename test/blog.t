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

`wodoc blog-llms` publishes the blog for AIs and LLMs: the Markdown twin of each
post, and the blog's `llms.txt` index and `llms-full.txt` dump. It reads odoc's
Markdown rendering of each post (`odoc markdown-generate` writes
`<slug>.md`); here two hand-written renderings stand in for it, in odoc's
shape: the `@author` tag comes out as an `author …` line glued to the first
paragraph, and a wodoc marker passes through verbatim.

  $ mkdir md
  $ cat > md/hello.md <<'MEOF'
  > 
  > # Hello world
  > 
  > author Alice
  > The first post's opening paragraph, which becomes the excerpt.
  > 
  > <!--wodoc:d:note-->
  > A note.
  > MEOF
  $ cat > md/second.md <<'MEOF'
  > 
  > # The second post
  > 
  > author Bob
  > A later post, so it sorts above the first one.
  > MEOF
  $ wodoc blog-llms --config doc/wodoc --md-dir md --out _blog --title "Demo Blog" \
  >   --summary "News from the demo project."

The index lists the posts newest first, each with its date, author and excerpt,
and links them by their twin's path relative to the blog root:

  $ cat _blog/llms.txt
  # Demo Blog
  
  > News from the demo project.
  
  ## Posts
  - [The second post](blog/second.md): Published on 2026-06-14 by Bob. A later post, so it sorts above the first one.
  - [Hello world](blog/hello.md): Published on 2026-06-10 by Alice. The first post's opening paragraph, which becomes the excerpt.

A twin carries the publication line under its title, in place of odoc's
`author` line, and the wodoc markers are gone:

  $ cat _blog/blog/hello.md
  # Hello world
  
  Published on 2026-06-10 by Alice.
  
  The first post's opening paragraph, which becomes the excerpt.
  
  A note.

`llms-full.txt` is the same header followed by every twin, newest first:

  $ grep -e '^#' -e '^Published' -e '^---' _blog/llms-full.txt
  # Demo Blog
  ---
  # The second post
  Published on 2026-06-14 by Bob.
  ---
  # Hello world
  Published on 2026-06-10 by Alice.

A post with no rendering fails the command, and nothing is written, so that the
twins already online are not replaced by half a set:

  $ rm md/hello.md
  $ wodoc blog-llms --config doc/wodoc --md-dir md --out _blog2
  wodoc blog-llms: cannot read the Markdown rendering of a post: md/hello.md: No such file or directory
  [1]
  $ test -e _blog2 || echo "nothing written"
  nothing written

A config with no `(blog …)` stanza is an error too:

  $ echo '(project demo)' > noblog
  $ wodoc blog-llms --config noblog --md-dir md --out _blog2
  wodoc blog-llms: noblog declares no (blog …)
  [1]

The real odoc rendering, on posts in the less common shapes: a title at level
one, two authors and a code block whose first line looks like a heading; and a
post with no author. The publication line lists both authors in place of
odoc's `author` lines, and stays out of the code block:

  $ mkdir -p edge/posts edge/md
  $ cat > edge/posts/2026-02-01-shapes.mld <<'MEOF'
  > {1 A title at level one}
  > 
  > @author Alice
  > @author Bob
  > 
  > Install it:
  > 
  > {@sh[
  > # from opam
  > opam install foo
  > ]}
  > MEOF
  $ cat > edge/posts/2026-02-02-anonymous.mld <<'MEOF'
  > {0 Nobody signs this one}
  > 
  > An anonymous post.
  > MEOF
  $ printf '(project edge)\n(blog (dir posts) (out posts))\n' > edge/wodoc
  $ for s in shapes anonymous; do
  >   wodoc preprocess edge/posts/2026-02-0?-$s.mld > edge/$s.mld
  >   odoc compile edge/$s.mld -o edge/page-$s.odoc 2>/dev/null
  >   odoc link edge/page-$s.odoc -o edge/page-$s.odocl
  >   odoc markdown-generate edge/page-$s.odocl -o edge/md
  > done
  $ wodoc blog-llms --config edge/wodoc --md-dir edge/md --out edge/out
  $ cat edge/out/posts/shapes.md
  ## A title at level one
  
  Published on 2026-02-01 by Alice, Bob.
  
  Install it:
  
  ```sh
  # from opam
  opam install foo
  ```
  $ head -3 edge/out/posts/anonymous.md
  # Nobody signs this one
  
  Published on 2026-02-02.
