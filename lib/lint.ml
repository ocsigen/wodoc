(* Every match of [re] in [s], mapped by [f] while [Str]'s match state is still
   the one of that match; [f] returning [None] drops it. *)
let collect re f s =
  let rec go acc pos =
    match Str.search_forward re s pos with
    | i ->
        let next = i + max 1 (String.length (Str.matched_string s)) in
        let acc = match f () with Some x -> x :: acc | None -> acc in
        go acc next
    | exception Not_found -> List.rev acc
  in
  go [] 0

let group n s = try Some (Str.matched_group n s) with Not_found -> None

let unresolved_re =
  Str.regexp
    "<span class=\"xref-unresolved[^\"]*\"\\( title=\"\\([^\"]*\\)\"\\)?>\\([^<]*\\)</span>"

let unresolved_refs ~ours page =
  let all =
    collect unresolved_re
      (fun () ->
         let of_group n =
           match group n page with
           | Some g when String.trim g <> "" -> Some (String.trim g)
           | _ -> None
         in
         match of_group 2 with Some title -> Some title | None -> of_group 3)
      page
  in
  List.partition ours all

(* A [{{file.png|alt}}] the wiki conversion left behind. The
   extension-then-pipe shape is the part no code sample can produce, so it is
   the part matched: the surrounding braces are not, odoc's rendering of the
   dead markup having swallowed some of them. *)
let wiki_image_re =
  Str.regexp_case_fold
    "{[^<>{}|]*\\.\\(png\\|jpe?g\\|gif\\|svg\\|webp\\)|[^<>{}]*"

let wiki_images page =
  collect wiki_image_re (fun () -> Some (Str.matched_string page)) page

exception Dead_markup of string

(* "3 unresolved references in 2 pages". The label comes as (singular, plural):
   a plural cannot be derived from a phrase -- "reference into a dependency this
   site does not host" pluralises on its first noun, at neither end. *)
let summary diagnostics (one, many) =
  let pages = List.length diagnostics in
  let items =
    List.fold_left (fun n (_, l) -> n + List.length l) 0 diagnostics
  in
  Printf.sprintf "%d %s in %d page%s" items
    (if items = 1 then one else many)
    pages
    (if pages = 1 then "" else "s")

let count diagnostics label =
  match diagnostics with
  | [] -> ()
  | _ -> prerr_endline ("wodoc: " ^ summary diagnostics label)

let report ~strict diagnostics ((one, _) as label) =
  match diagnostics with
  | [] -> ()
  | _ ->
      List.iter
        (fun (page, items) ->
           Printf.eprintf "wodoc: %s: %s: %s\n" page one
             (String.concat ", " items))
        (List.rev diagnostics);
      let msg = "wodoc: " ^ summary diagnostics label in
      if strict
      then raise (Dead_markup msg)
      else prerr_endline (msg ^ " (--strict-refs makes this fatal)")
