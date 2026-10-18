(** The manual's page tree, as odoc shows it in its sidebar.

    odoc 3 builds a tree from the manual's directories: each subdirectory of
    [odoc-pages/] is a node, its [index.mld] gives the node title (or
    [@short_title]) and the order of its children ([@children_order]). The
    generated pages show that tree in their sidebar, and ocaml.org shows it as
    is. odoc_driver also writes it as data, in a [sidebar.json] next to each
    package's pages. This module reads it, so that wodoc's left column follows
    the same tree. *)

exception Missing of string
(** Raised by {!items} when the tree cannot be read, or does not show the
    expected page. *)

val has_sidebar : src:string -> string -> bool
(** [has_sidebar ~src page] is [true] if odoc_driver wrote the sidebar of the
    page [page] of the odoc HTML tree [src]: a [sidebar.json] in the page's
    directory or above it, up to [src]. *)

val items : src:string -> string -> Config.expanded Config.item list
(** [items ~src index] is the manual tree of the page [index] of the odoc HTML
    tree [src], as nav items: [index] itself (unless odoc does not link it, for
    a directory with [@toc_status hidden]), then the pages and directories
    below it. A page is a {!Config.Link}, a directory a {!Config.Group}, linked
    to its index page when odoc makes it clickable. The libraries and the
    source tree are left out: wodoc renders the API navigation separately.

    [index] is a page path relative to [src]. For a directory hidden with
    [@toc_status hidden], [index] is its [index.html] page, which odoc does not
    link.

    @raise Missing if there is no [sidebar.json] for [index], if it cannot be
    read, or if it does not show [index]. *)
