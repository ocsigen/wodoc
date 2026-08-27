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

let unresolved_refs page =
  collect unresolved_re
    (fun () ->
       let of_group n =
         match group n page with
         | Some g when String.trim g <> "" -> Some (String.trim g)
         | _ -> None
       in
       match of_group 2 with Some title -> Some title | None -> of_group 3)
    page

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

let report ~strict diagnostics kind =
  match diagnostics with
  | [] -> ()
  | _ ->
      let pages = List.length diagnostics in
      let total =
        List.fold_left (fun n (_, l) -> n + List.length l) 0 diagnostics
      in
      List.iter
        (fun (page, items) ->
           Printf.eprintf "wodoc: %s: %s: %s\n" page kind
             (String.concat ", " items))
        (List.rev diagnostics);
      let msg =
        Printf.sprintf "wodoc: %d %s%s in %d page%s" total kind
          (if total = 1 then "" else "s")
          pages
          (if pages = 1 then "" else "s")
      in
      if strict
      then raise (Dead_markup msg)
      else prerr_endline (msg ^ " (--strict-refs makes this fatal)")
