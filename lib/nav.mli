(** Build a manual's left-column navigation from its wikicréole menu.

    The OCaml port of the per-project [gen-manual-nav.py] scripts: one
    implementation, the per-project differences (page location, API landing
    map, heading) given as options. *)

val manual :
   ?pkg:string
  -> ?heading:string
  -> ?api_map:(string * string) list
  -> base:string
  -> string
  -> string
(** [manual ~base menu] renders the [<nav>] for the wiki menu source [menu].
    - [pkg] (default [""]): package dir holding the manual pages; [""] puts a
      [[page|T]] link at [<base>/<page>.html], otherwise [<base>/<pkg>/<page>.html].
    - [heading] (default ["Manual"]): the [<h3>] label.
    - [api_map] (default [[]]): subproject -> path (relative to [base]) for
      [<<a_api>>] landings; an unknown subproject falls back to
      [<subproject>/index.html]. *)

val api :
   ?wrapper:string
  -> ?heading:string
  -> ?skip:string list
  -> base:string
  -> lib:string
  -> string
  -> string
(** [api ~base ~lib indexdoc] renders the API module [<nav>] from a curated odoc
    index ([{N title}] sections + [{!modules: …}] lists). The OCaml port of
    [gen-nav.py]. A module path [A.B.C] maps to
    [<base>/<lib>/[<wrapper>/]A/B/C/index.html]. [skip] lists section titles to
    drop (page titles, [Index]); [heading] is the [<h3>] (default ["Modules"]). *)

val anchors : ?heading:string -> base:string -> string -> string
(** [anchors ~base menu] renders a single-page manual's [<nav>] from a wiki menu
    of in-page anchor links [\[\[#anchor|Title\]\]] (-> [<base>/index.html#anchor]),
    cleaning [{{{…}}}]/[##…##] markup from titles. The OCaml port of
    [gen-anchor-nav.py]. *)
