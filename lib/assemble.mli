(** Assembly layer: wrap odoc's rendered HTML in a project-provided site
    template.

    wodoc stays generic: the project owns all of its chrome (header, menus,
    drawer, footer, version selector) as a plain HTML {e template} with named
    holes. This module only:
    - extracts the meaningful parts from odoc's HTML output ({!Parts.of_odoc_html});
    - fills the holes of the template ({!fill});
    - marks the current navigation entry ({!mark_current}).

    A template is HTML containing holes written [{{name}}]. The standard holes
    filled by {!page} are [{{title}}], [{{preamble}}], [{{toc}}] and
    [{{content}}]. Menu links carry a [data-wodoc-page] attribute; the entry
    whose value equals the current page id receives the [current] class. *)

module Parts : sig
  type t =
    { title : string  (** plain text of the page's [<h1>] *)
    ; preamble : string  (** the [odoc-preamble] header, verbatim *)
    ; toc : string  (** the [odoc-tocs] block, verbatim (may be empty) *)
    ; content : string  (** the [odoc-content] block, verbatim *) }

  val of_odoc_html : string -> t
  (** Extract the parts from a full odoc-generated HTML page. *)
end

val fill : template:string -> (string * string) list -> string
(** [fill ~template bindings] replaces every [{{key}}] in [template] with its
    bound value. Unbound holes are left untouched. *)

val mark_current :
   ?attr:string
  -> ?class_:string
  -> current:string
  -> string
  -> string
(** [mark_current ~current html] adds [class_] (default ["current"]) to every
    start tag whose [attr] (default ["data-wodoc-page"]) equals [current],
    merging with an existing [class]. [current = ""] marks nothing. *)

val page :
   ?preamble:bool
  -> template:string
  -> current:string
  -> string
  -> string
(** [page ~template ~current odoc_html] is the convenience pipeline:
    {!Parts.of_odoc_html}, then {!fill} of the standard holes, then
    {!mark_current}. [preamble] (default [true]) controls whether the page's
    [<h1>] title block fills the [{{preamble}}] hole; pass [false] for pages
    that should not show a title. *)
