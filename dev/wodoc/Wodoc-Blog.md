# Module `Wodoc.Blog`

```ocaml
type post = {
  date : string; (* publication date "YYYY-MM-DD", taken from the file name *)
  slug : string; (* the file-name part after the date, e.g. "first-post" *)
  src : string; (* path to the post's .mld source *)
  path : string; (* deployed page path, relative to the version root, e.g. "blog/first-post.html" *)
  title : string; (* the post's {1 …} / {0 …} heading, as plain text *)
  author : string; (* the odoc @author … tags, plain text, joined with ", " ("" when absent) *)
  excerpt : string; (* first paragraph of the body, plain text (may be "") *)
}
```
```ocaml
val posts : Config.blog -> post list
```
`posts blog`: the posts found in `blog.dir` (file names `YYYY-MM-DD-slug.mld`), newest first. Files that do not match the dated naming are skipped.

```ocaml
val nav_section : Config.blog -> post list -> _ Config.section
```
`nav_section blog posts`: a synthetic left-nav [`Config.section`](./Wodoc-Config.md#type-section) listing the posts (heading `blog.heading`, one link per post), to splice into the config nav. The link label is "date, title".

```ocaml
val nav_html : base:string -> Config.blog -> post list -> string
```
`nav_html ~base blog posts`: the blog's left-nav block as a `<nav class="api-nav manual-nav">` (an `<h3>` \+ one `<li>` per post), rendered like a manual nav section so the shared CSS styles it. For the low-level `wodoc assemble --leftnav` path; the turn-key `wodoc build` path splices [`nav_section`](./#val-nav_section) instead. `base` is the page's relative path to the blog root.

```ocaml
val feed : 
  base_url:string ->
  blog_path:string ->
  feed_path:string ->
  title:string ->
  author:string ->
  post list ->
  string
```
`feed ~base_url ~blog_path ~feed_path ~title ~author posts`: an Atom feed of the posts (newest first), for syndication (e.g. OCaml Planet). `base_url` is the site origin; a post's URL is `base_url ^ blog_path ^ "/" ^ post.path`; the feed advertises itself at `base_url ^ feed_path`. Entry bodies are the post excerpt as an HTML summary; the feed `updated` is the newest post's date.

```ocaml
val md_path : post -> string
```
`md_path post`: the deployed path of the post's Markdown twin, relative to the blog root: `post.path` with an `.md` extension.

```ocaml
val markdown_twin : post -> string -> string
```
`markdown_twin post md`: the Markdown twin of `post`, from odoc's Markdown rendering `md` of its page. The wodoc markers are dropped ([`Render.markdown`](./Wodoc-Render.md#val-markdown)) and a `"Published on <date> by <author>."` line replaces the `author` lines odoc renders under the title: it is the Markdown counterpart of the HTML byline. A page that does not start with a title gets the line first.

```ocaml
val write_llms : 
  md_dir:string ->
  out:string ->
  title:string ->
  summary:string ->
  post list ->
  (unit, string) Stdlib.result
```
`write_llms ~md_dir ~out ~title ~summary posts` writes, under the blog root `out`, the [`markdown_twin`](./#val-markdown_twin) of each post at its [`md_path`](./#val-md_path), then the LLM-friendly index files, following the llms.txt convention (llmstxt.org):

- `llms.txt`: `# title`, a `>` blockquote `summary`, then a `## Posts` section listing the posts newest first, each as `- [title](md path): Published on <date> by <author>. <excerpt>`;
- `llms-full.txt`: every twin concatenated, for single-shot ingestion.
The rendering of a post is read from `md_dir/<slug>.md`, where `odoc markdown-generate` writes it. Every rendering is read first: if one cannot be read, the result is `Error msg` and nothing is written. A file that cannot be written also gives `Error msg`.

```ocaml
val latest_fragment : base:string -> Config.blog -> post list -> string
```
`latest_fragment ~base blog posts`: the HTML fragment that the `{%wodoc:blog-latest%}` marker expands to: a `<ul class="wodoc-blog-list">` of the `blog.latest` most recent posts (title, date, author, excerpt, link), each link prefixed with `base` (the per-page relative root). Empty when there are no posts.

```ocaml
val marker : string
```
the marker the landing uses to request [`latest_fragment`](./#val-latest_fragment). wodoc rewrites `{%wodoc:blog-latest%}` to this HTML comment in [`Preprocess`](./Wodoc-Preprocess.md); [`expand`](./#val-expand) turns it back into the fragment.

```ocaml
val expand : fragment:string -> string -> string
```
`expand ~fragment html`: replace every [`marker`](./#val-marker) comment in `html` with `fragment`. A no-op when the page carries no marker.
