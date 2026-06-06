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
