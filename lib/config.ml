(* The declarative wodoc project configuration: one [doc/wodoc] file per project
   replaces its build.sh and its menu.wiki. Read by {!Build}. *)

type entry =
  { label : string  (** visible text *)
  ; path : string  (** href relative to the version root (filled with base) *)
  ; current : string  (** data-wodoc-page id (highlighted on its own pages) *) }

type section =
  { heading : string  (** the [<h3>] label of this left-nav block *)
  ; api : bool  (** [api-section] -> class "api-nav"; else "api-nav manual-nav" *)
  ; entries : entry list }

type t =
  { project : string  (** package / project id, e.g. "ocsipersist" *)
  ; title : string  (** sub-project label by the logo, e.g. "Ocsipersist" *)
  ; pub : string  (** absolute publish base for the version selector, e.g. "/ocsipersist" *)
  ; menu_current : string  (** project id highlighted in the shared top menu *)
  ; packages : string list  (** odoc output subtrees to assemble, in order *)
  ; landing : string  (** index.html redirect target, e.g. "ocsipersist/index.html" *)
  ; highlight : string option  (** project highlight.js to ship, if any *)
  ; profile : string option  (** dune build profile (e.g. "release") *)
  ; odoc_driver : string option
      (** when set, build the API with [odoc_driver <pkg> --remap] (the engine
          ocaml.org uses) instead of [dune build @doc]: needed for a client/server
          package whose [<pkg>.server]/[<pkg>.client] libraries share module names
          and would collide under [dune build @doc] (eliom, ocsigen-toolkit,
          ocsigen-start). *)
  ; doc_manual : bool  (** also build the [@doc-manual] alias (examples) *)
  ; manual_files : string option  (** package dir to receive manual/files (examples, images) *)
  ; siblings : (string * string list) list  (** resolve-refs sibling table *)
  ; nav : section list }

let parse_entry = function
  | Sexp.List [ Atom label; Atom path; Atom current ] -> { label; path; current }
  | Sexp.List [ Atom label; Atom path ] -> { label; path; current = "" }
  | _ -> raise (Sexp.Error "bad (link <label> <path> [<current>]) entry")

let parse_section api = function
  | Sexp.List (Atom heading :: links) ->
      { heading; api
      ; entries =
          List.filter_map
            (function
              | Sexp.List (Atom "link" :: rest) -> Some (parse_entry (List rest))
              | _ -> None)
            links }
  | _ -> raise (Sexp.Error "bad nav section")

let parse_nav stanzas =
  match Sexp.fields "nav" stanzas with
  | blocks :: _ ->
      List.filter_map
        (function
          | Sexp.List (Atom "section" :: rest) -> Some (parse_section false (List rest))
          | Sexp.List (Atom "api-section" :: rest) -> Some (parse_section true (List rest))
          | _ -> None)
        blocks
  | [] -> []

let parse_siblings stanzas =
  List.filter_map
    (function
      | [ Sexp.Atom m; Sexp.Atom segs ] ->
          Some (m, List.filter (fun s -> s <> "") (String.split_on_char '/' segs))
      | _ -> None)
    (Sexp.fields "sibling" stanzas)

let of_string s =
  let stanzas = Sexp.parse s in
  let project =
    match Sexp.field_atom "project" stanzas with
    | Some p -> p
    | None -> raise (Sexp.Error "missing (project ...)")
  in
  { project
  ; title = Sexp.field_atom_default "title" project stanzas
  ; pub = Sexp.field_atom_default "pub" ("/" ^ project) stanzas
  ; menu_current = Sexp.field_atom_default "menu-current" project stanzas
  ; packages = Sexp.field_atoms "packages" stanzas
    (* [] = assemble every subtree odoc produced (see Build) *)
  ; landing = Sexp.field_atom_default "landing" (project ^ "/index.html") stanzas
  ; highlight = Sexp.field_atom "highlight" stanzas
  ; profile = Sexp.field_atom "profile" stanzas
  ; odoc_driver = Sexp.field_atom "odoc-driver" stanzas
  ; doc_manual = Sexp.field_atom "doc-manual" stanzas = Some "true"
  ; manual_files = Sexp.field_atom "manual-files" stanzas
  ; siblings = parse_siblings stanzas
  ; nav = parse_nav stanzas }
