let find s sub from =
  let len = String.length s and sl = String.length sub in
  let rec go j =
    if j + sl > len
    then None
    else if String.sub s j sl = sub
    then Some j
    else go (j + 1)
  in
  go from

(* [extract_block s ~opening ~tag] returns the substring from the literal
   [opening] to the matching close [</tag>], balancing nested [<tag] opens. *)
let extract_block s ~opening ~tag =
  match find s opening 0 with
  | None -> ""
  | Some start -> (
      let len = String.length s in
      let openp = "<" ^ tag and closep = "</" ^ tag ^ ">" in
      let depth = ref 0 and i = ref start and stop = ref None in
      while !stop = None && !i < len do
        if
          !i + String.length closep <= len
          && String.sub s !i (String.length closep) = closep
        then (
          decr depth;
          if !depth = 0
          then stop := Some (!i + String.length closep)
          else incr i)
        else if
          !i + String.length openp <= len
          && String.sub s !i (String.length openp) = openp
        then (
          incr depth;
          i := !i + String.length openp)
        else incr i
      done;
      match !stop with Some e -> String.sub s start (e - start) | None -> "")

let strip_tags s =
  let b = Buffer.create (String.length s) in
  let depth = ref 0 in
  String.iter
    (fun c ->
       if c = '<'
       then incr depth
       else if c = '>'
       then (if !depth > 0 then decr depth)
       else if !depth = 0
       then Buffer.add_char b c)
    s;
  String.trim (Buffer.contents b)

module Parts = struct
  type t = {title : string; preamble : string; toc : string; content : string}

  let of_odoc_html s =
    let preamble =
      extract_block s ~opening:"<header class=\"odoc-preamble\">" ~tag:"header"
    in
    let toc = extract_block s ~opening:"<div class=\"odoc-tocs\">" ~tag:"div" in
    let content =
      extract_block s ~opening:"<div class=\"odoc-content\">" ~tag:"div"
    in
    let title =
      match find s "<h1" 0 with
      | Some h -> (
        match find s "</h1>" h with
        | Some e -> strip_tags (String.sub s h (e + 5 - h))
        | None -> "")
      | None -> ""
    in
    {title; preamble; toc; content}
end

let fill ~template bindings =
  List.fold_left
    (fun acc (key, value) ->
       let hole = "{{" ^ key ^ "}}" in
       let b = Buffer.create (String.length acc) in
       let len = String.length acc in
       let i = ref 0 in
       while !i < len do
         match find acc hole !i with
         | None ->
             Buffer.add_substring b acc !i (len - !i);
             i := len
         | Some p ->
             Buffer.add_substring b acc !i (p - !i);
             Buffer.add_string b value;
             i := p + String.length hole
       done;
       Buffer.contents b)
    template bindings

let mark_current ?(attr = "data-wodoc-page") ?(class_ = "current") ~current s =
  if current = ""
  then s
  else
    let needle = Printf.sprintf "%s=\"%s\"" attr current in
    let len = String.length s in
    let out = Buffer.create len in
    let i = ref 0 in
    while !i < len do
      match find s needle !i with
      | None ->
          Buffer.add_substring out s !i (len - !i);
          i := len
      | Some p -> (
          (* find the start '<' of the tag containing this attribute *)
          let tagstart =
            let j = ref p in
            while !j > 0 && s.[!j] <> '<' do
              decr j
            done;
            !j
          in
          match find s ">" p with
          | None ->
              Buffer.add_substring out s !i (len - !i);
              i := len
          | Some gt ->
              Buffer.add_substring out s !i (tagstart - !i);
              let tag = String.sub s tagstart (gt - tagstart + 1) in
              let has_class =
                try
                  ignore
                    (Str.search_forward
                       (Str.regexp
                          ("class=\"\\([^\"]*\\b\\)?" ^ Str.quote class_ ^ "\\b"))
                       tag 0);
                  true
                with Not_found -> false
              in
              let tag =
                if has_class (* already marked: idempotent, leave as-is *)
                then tag
                else if Str.string_match (Str.regexp ".*class=\"") tag 0
                then
                  Str.replace_first
                    (Str.regexp "class=\"\\([^\"]*\\)\"")
                    (Printf.sprintf "class=\"\\1 %s\"" class_)
                    tag
                else
                  String.sub tag 0 (String.length tag - 1)
                  ^ Printf.sprintf " class=\"%s\">" class_
              in
              Buffer.add_string out tag;
              i := gt + 1)
    done;
    Buffer.contents out

(* odoc 3.x's sidebar is a global page/library tree, not a per-page section toc,
   so reusing it for an "On this page" panel just duplicates the manual/API
   navigation. Synthesise a real local toc from the rendered content's heading
   anchors (<h2 id>/<h3 id>/<h4 id>), nested by level. Returns "" when the page
   has no sections (the theme hides the panel via the odoc-local-toc class). *)
let local_toc content =
  let len = String.length content in
  let items = ref [] in
  let i = ref 0 in
  while !i < len do
    if
      !i + 3 <= len
      && content.[!i] = '<'
      && content.[!i + 1] = 'h'
      && (content.[!i + 2] = '2'
         || content.[!i + 2] = '3'
         || content.[!i + 2] = '4')
    then
      let lvl = Char.code content.[!i + 2] - Char.code '0' in
      match find content ">" !i with
      | None -> i := len
      | Some gt -> (
          let opentag = String.sub content !i (gt - !i + 1) in
          let close = Printf.sprintf "</h%d>" lvl in
          match find content close (gt + 1) with
          | None -> i := gt + 1
          | Some ce ->
              (if
                 Str.string_match (Str.regexp ".*id=\"\\([^\"]*\\)\"") opentag 0
               then
                 let id = Str.matched_group 1 opentag in
                 let title =
                   strip_tags (String.sub content (gt + 1) (ce - gt - 1))
                 in
                 if title <> "" then items := (lvl, id, title) :: !items);
              i := ce + String.length close)
    else incr i
  done;
  let items = List.rev !items in
  if items = []
  then ""
  else
    let minlvl = List.fold_left (fun m (l, _, _) -> min m l) 9 items in
    let b = Buffer.create 256 in
    let depth = ref 0 in
    List.iter
      (fun (lvl, id, title) ->
         let d = lvl - minlvl + 1 in
         if d > !depth
         then
           for _ = !depth + 1 to d do
             Buffer.add_string b "<ul>"
           done
         else (
           Buffer.add_string b "</li>";
           for _ = d + 1 to !depth do
             Buffer.add_string b "</ul></li>"
           done);
         depth := d;
         Buffer.add_string b
           (Printf.sprintf "<li><a href=\"#%s\">%s</a>" id title))
      items;
    Buffer.add_string b "</li>";
    for _ = 2 to !depth do
      Buffer.add_string b "</ul></li>"
    done;
    Buffer.add_string b "</ul>";
    Printf.sprintf "<nav class=\"odoc-toc odoc-local-toc\">%s</nav>"
      (Buffer.contents b)

(* strip the outermost start/end tag of a balanced block: "<t ...>X</t>" -> "X" *)
let inner block =
  match String.index_opt block '>' with
  | None -> block
  | Some gt ->
      let last =
        try String.rindex block '<' with Not_found -> String.length block
      in
      if last > gt then String.sub block (gt + 1) (last - gt - 1) else ""

let page
      ?(preamble = true)
      ?(flat = false)
      ?(strip_anchors = true)
      ?(base = "")
      ?(menu = "")
      ?(subproject = "")
      ?(menu_current = "")
      ?(leftnav = "")
      ~template
      ~current
      odoc_html
  =
  let p = Parts.of_odoc_html odoc_html in
  (* The content fragment is rendered here (not the template, whose chrome must
     not go through the hoist pass). In [flat] mode, sections may span the
     odoc preamble/content boundary, so concatenate their inner HTML — without
     the <header>/<div odoc-content> wrappers — before rendering, so paired
     wodoc markers are balanced. *)
  let fragment =
    if flat then inner p.preamble ^ "\n" ^ inner p.content else p.content
  in
  let content = Render.html ~strip_anchors fragment in
  (* Highlight the current project in the shared menu, scoped to the menu
     fragment so it cannot also hit a left-nav entry that happens to share the
     id (a project id like "ocsipersist" equals its main package id). *)
  let menu =
    if menu_current = "" then menu else mark_current ~current:menu_current menu
  in
  let filled =
    fill ~template
      [ (* The shared menu fragment goes in first: it may itself contain holes
           ([{{subproject}}], [{{base}}]) that the later bindings then fill. *)
        "menu", menu
      ; (* both slots of the left navigation (drawer + left column), wherever
           [{{leftnav}}] appears in the menu fragment or the template *)
        "leftnav", leftnav
      ; "subproject", subproject
      ; "base", base
      ; "title", p.title
      ; ( "preamble"
        , if flat || not preamble
          then ""
          else Render.html ~strip_anchors p.preamble )
        (* a real per-page "On this page", synthesised from the content's
           section headings (odoc 3.x only gives a global page tree) *)
      ; "toc", local_toc content
      ; "content", content ]
  in
  (* [current] marks the in-page nav entry: the menu page id on the vitrine, or
     the API package / module in a project's left column. The menu was already
     marked above (scoped), and [mark_current] is idempotent, so re-touching a
     menu entry whose id equals [current] is harmless. *)
  mark_current ~current filled
