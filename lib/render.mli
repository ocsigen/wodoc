(** wodoc rendering pass over odoc's HTML output.

    odoc emits the [{%html:<!--wodoc:DIRECTIVE-->%}] markers produced by
    {!Preprocess} as HTML comments. This pass turns those comments into real,
    correctly nested HTML and removes the [<p>] wrappers odoc forces around
    inline raw-markup.

    Supported directives (the content after [wodoc:]):
    - [div class=...] / [a class=... href=...] / [span class=...] open a
      container, paired with [end] which closes the most recent one;
    - [\@ key=val ...] adds attributes to the {e next} HTML element (the [\@\@]
      equivalent: a [class] is merged with any existing one);
    - [img src=... class=... alt=...] emits a self-contained [<img>].

    The directive set is intentionally small and generic; project-specific
    widgets (menus, switches…) belong to the assembly layer, not here. *)

val html : string -> string
(** [html s] processes the wodoc markers in odoc's HTML [s] and returns the
    transformed HTML. Markers are consumed; on malformed input the offending
    marker is left as an HTML comment rather than raising. *)
