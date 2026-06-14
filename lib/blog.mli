(* An ultra-simple blog for wodoc sites: a directory of dated [.mld] posts that
   build like any other page, are auto-listed in a left-nav section, and whose
   most recent entries are inlined on the landing via [{%wodoc:blog-latest%}].
   Generic — no project-specific assumptions. Driven by {!Config.blog}. *)

type post =
  { date : string  (** publication date "YYYY-MM-DD", taken from the file name *)
  ; slug : string  (** the file-name part after the date, e.g. "first-post" *)
  ; src : string  (** path to the post's [.mld] source *)
  ; path : string
    (** deployed page path, relative to the version root, e.g. "blog/first-post.html" *)
  ; title : string  (** the post's [{1 …}] / [{0 …}] heading, as plain text *)
  ; author : string  (** odoc [@author …], plain text ("" when absent) *)
  ; excerpt : string  (** first paragraph of the body, plain text (may be "") *)
  }

val posts : Config.blog -> post list
(** [posts blog]: the posts found in [blog.dir] (file names [YYYY-MM-DD-slug.mld]),
    newest first. Files that do not match the dated naming are skipped. *)

val nav_section : Config.blog -> post list -> Config.section
(** [nav_section blog posts]: a synthetic left-nav {!Config.section} listing the
    posts (heading [blog.heading], one link per post), to splice into the config
    nav. The link label is "date — title". *)

val nav_html : base:string -> Config.blog -> post list -> string
(** [nav_html ~base blog posts]: the blog's left-nav block as a
    [<nav class="api-nav manual-nav">] (an [<h3>] + one [<li>] per post),
    rendered like a manual nav section so the shared CSS styles it. For the
    low-level [wodoc assemble --leftnav] path; the turn-key [wodoc build] path
    splices {!nav_section} instead. [base] is the page's relative path to the
    blog root. *)

val feed :
   base_url:string
  -> blog_path:string
  -> feed_path:string
  -> title:string
  -> author:string
  -> post list
  -> string
(** [feed ~base_url ~blog_path ~feed_path ~title ~author posts]: an Atom feed of
    the posts (newest first), for syndication (e.g. OCaml Planet). [base_url] is
    the site origin; a post's URL is [base_url ^ blog_path ^ "/" ^ post.path]; the
    feed advertises itself at [base_url ^ feed_path]. Entry bodies are the post
    excerpt as an HTML summary; the feed [updated] is the newest post's date. *)

val latest_fragment : base:string -> Config.blog -> post list -> string
(** [latest_fragment ~base blog posts]: the HTML fragment that the
    [{%wodoc:blog-latest%}] marker expands to — a [<ul class="wodoc-blog-list">]
    of the [blog.latest] most recent posts (title, date, author, excerpt, link),
    each link prefixed with [base] (the per-page relative root). Empty when there
    are no posts. *)

val marker : string
(** the marker the landing uses to request {!latest_fragment}. wodoc rewrites
    [{%wodoc:blog-latest%}] to this HTML comment in {!Preprocess}; {!val:expand}
    turns it back into the fragment. *)

val expand : fragment:string -> string -> string
(** [expand ~fragment html]: replace every {!marker} comment in [html] with
    [fragment]. A no-op when the page carries no marker. *)
