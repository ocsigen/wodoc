(** Link cross-package "sibling" references odoc left unresolved.

    odoc only resolves references along dependency edges, so a reference to a
    sibling package built in the same tree (but not a dependency) is rendered as
    an [xref-unresolved] span or a bare [<code>] and left dead. This rewrites
    those into relative links within the version's output. The OCaml port of the
    per-project [resolve-siblings.py] scripts; one implementation, the sibling
    table given as data. *)

val html_escape : string -> string
(** HTML-escape the five characters amp, lt, gt, quote and apostrophe (like
    Python's [html.escape]). *)

val link_for : (string * string list) list -> string -> string -> string option
(** [link_for siblings base raw] is the relative URL for the qualified name
    [raw] (possibly carrying a ["val "]/["type "]/… kind prefix) when it is
    rooted at a known sibling, else [None]. [siblings] maps a top module to the
    path segments of its own directory under the version root (e.g.
    ["Ppx_lwt"] -> [["lwt_ppx"; "Lwt_ppx"; "Ppx_lwt"]]); [base] is the relative
    path from the page to that root. *)

val html : siblings:(string * string list) list -> base:string -> string -> string
(** [html ~siblings ~base page] rewrites every sibling reference in [page]
    (both [xref-unresolved] spans and bare [<code>] qualified names), outside
    [<pre>] blocks, and returns the new HTML. *)
