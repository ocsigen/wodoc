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

val html :
   siblings:(string * string list) list
  -> base:string
  -> string
  -> string
(** [html ~siblings ~base page] rewrites every sibling reference in [page]
    (both [xref-unresolved] spans and bare [<code>] qualified names), outside
    [<pre>] blocks, and returns the new HTML. *)

(** How a hosted project's modules are laid out under [<dir>/latest/]. *)
type layout =
  | Multilib  (** client/server libs under [<dir>.<side>/], path flattened *)
  | Root  (** single package at the version root, path flattened *)
  | Subdir
  (** multi-package project, each opam package under its own [<pkg>/], odoc
          module layout kept verbatim *)

val layout_of_string : string -> layout
(** Parse a [hosted] layout token: ["multilib"]/["true"] -> [Multilib],
    ["subdir"] -> [Subdir], anything else (["root"]/["false"]) -> [Root]. *)

val deps :
   hosted:(string * (string * layout * string)) list
  -> relroot:string
  -> side:string
  -> self:string
  -> string
  -> string
(** [deps ~hosted ~relroot ~side ~self page] rewrites cross-PROJECT references
    to a hosted Ocsigen project into relative links: both resolved ocaml.org
    dep links and [xref-unresolved] spans. [hosted] maps a package to
    [(dir, layout, wrapper)]; a [Subdir] entry also matches any package
    extending its key with a [-]/[_] separator (whole-family match). [relroot]
    is the path from the page to the shared root holding every project; [side]
    is ["server"]/["client"]/[""]; [self] is the package being documented (its
    own leftover refs are kept as text). The OCaml port of [resolve-deps.py]. *)

val requalify :
   wrapped:(string * string) list
  -> exists:(string -> bool)
  -> string
  -> string
(** [requalify ~wrapped ~exists page] rewrites flat cross-project links to a
    wrapped library's module (e.g. [.../eliom.server/Eliom_content/…], emitted by
    [odoc_driver --remap]) into the qualified path the target deploys
    ([.../eliom.server/Eliom/Content/…]). [wrapped] maps a project deploy-dir to
    its wrapper module ([("eliom","Eliom")]). The flat→qualified mapping is not
    uniform (renamed vs kept module names), so each candidate is probed with
    [exists] (the caller resolves the candidate URL against the page's location
    and stats the target). *)
