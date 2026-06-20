(** Built-in default assets shipped by [wodoc build], so it produces a styled,
    self-contained site with no theme setup. Each is overridable: the
    stylesheet via the [(css …)] config stanza, the top menu via [--menu]. *)

val menu : string
(** The default top-menu fragment, injected when [--menu] is not given. Contains
    the [{{subproject}}] hole (filled with the project title). *)

val css : string
(** The default stylesheet, shipped as [wodoc.css] and linked per-version when no
    [(css …)] is configured. Themes both the wodoc chrome and the odoc content. *)
