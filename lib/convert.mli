(** Best-effort converter from extended wikicréole to odoc [.mld] with wodoc
    markers.

    This is a migration aid, not a full wikicréole parser: it handles the common
    constructs (headings, bold/italic/monospace, links, lists, code blocks,
    [<<div class="...">>] / [<<span>>] / [<<header>>] wrappers, [<<|...>>]
    comments, [@@class@@] attributes, images, [\\] line breaks). Converted pages
    are expected to be reviewed by hand. *)

val wiki_to_mld : string -> string
(** [wiki_to_mld s] converts wikicréole source [s] to a wodoc [.mld] string. *)
