(** Best-effort converter from extended wikicréole to odoc [.mld] with wodoc
    markers.

    This is a migration aid, not a full wikicréole parser: it handles the common
    constructs (headings, bold/italic/monospace, links, lists, code blocks,
    [<<div class="...">>] / [<<span>>] / [<<header>>] wrappers, [<<|...>>]
    comments, [@@class@@] attributes, images, line breaks). Converted pages
    are expected to be reviewed by hand. *)

val wiki_to_mld : ?default_side:string -> ?odoc_refs:bool -> string -> string
(** [wiki_to_mld s] converts wikicréole source [s] to a wodoc [.mld] string.

    [default_side] (e.g. ["server"]/["client"], default [""]) controls plain
    [<<a_api|...>>] references carrying neither [subproject] nor [project]: when
    set, they link into that side of the API ([../<pkg>.<side>/...]) rather than
    becoming an in-package odoc reference — used for a sided project's manual,
    whose bare API references are understood to be server-side.

    [odoc_refs] (default [false]): emit native odoc references for [a_api]
    ([{!Name}]) and [a_manual] ([{{!page-"c"}…}]) instead of relative URLs. Use
    this when the manual is built in the SAME odoc run as the API (unified
    in-package build), where such references resolve. [default_side] is then
    irrelevant. *)
