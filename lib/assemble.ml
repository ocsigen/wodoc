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
              let tag =
                if Str.string_match (Str.regexp ".*class=\"") tag 0
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
  let filled =
    fill ~template
      [ "base", base
      ; "title", p.title
      ; ( "preamble"
        , if flat || not preamble
          then ""
          else Render.html ~strip_anchors p.preamble )
        (* headings can carry wodoc markers (e.g. inline code spans), which odoc
           copies verbatim into the toc; render them here too *)
      ; "toc", Render.html ~strip_anchors p.toc
      ; "content", content ]
  in
  mark_current ~current filled
