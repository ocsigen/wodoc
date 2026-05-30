let mopen = "<!--wodoc:"
let mclose = "-->"

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

(* Parse [key=val key2="val with spaces"] into an assoc list. Values may be
   double-quoted (to hold spaces, e.g. several CSS classes) or bare (no space). *)
let parse_attrs s =
  let n = String.length s in
  let i = ref 0 in
  let acc = ref [] in
  while !i < n do
    while !i < n && s.[!i] = ' ' do
      incr i
    done;
    if !i < n
    then begin
      let ks = !i in
      while !i < n && s.[!i] <> '=' && s.[!i] <> ' ' do
        incr i
      done;
      let key = String.sub s ks (!i - ks) in
      if !i < n && s.[!i] = '='
      then begin
        incr i;
        let value =
          if !i < n && s.[!i] = '"'
          then begin
            incr i;
            let vs = !i in
            while !i < n && s.[!i] <> '"' do
              incr i
            done;
            let v = String.sub s vs (!i - vs) in
            if !i < n then incr i;
            v
          end
          else begin
            let vs = !i in
            while !i < n && s.[!i] <> ' ' do
              incr i
            done;
            String.sub s vs (!i - vs)
          end
        in
        if key <> "" then acc := (key, value) :: !acc
      end
    end
  done;
  List.rev !acc

let attrs_to_html attrs =
  String.concat ""
    (List.map (fun (k, v) -> Printf.sprintf " %s=\"%s\"" k v) attrs)

let attrs_of s = attrs_to_html (parse_attrs s)

(* split a directive into its first word (kind) and the remaining attr string *)
let kind_and_rest d =
  match String.index_opt d ' ' with
  | Some k -> String.sub d 0 k, String.sub d (k + 1) (String.length d - k - 1)
  | None -> d, ""

(* Pass 1: markers -> tags / void elements / attr-sentinels, tracking an
   open/[end] stack for paired containers. *)
let emit_tags s =
  let out = Buffer.create (String.length s) in
  let stack = ref [] in
  let len = String.length s in
  let i = ref 0 in
  while !i < len do
    match find s mopen !i with
    | None ->
        Buffer.add_substring out s !i (len - !i);
        i := len
    | Some start -> (
        Buffer.add_substring out s !i (start - !i);
        let cstart = start + String.length mopen in
        match find s mclose cstart with
        | None ->
            Buffer.add_substring out s start (len - start);
            i := len
        | Some cend ->
            let d = String.trim (String.sub s cstart (cend - cstart)) in
            let kind, rest = kind_and_rest d in
            (match kind with
            | "end" -> (
              match !stack with
              | t :: tl ->
                  Buffer.add_string out t;
                  stack := tl
              | [] -> Buffer.add_string out "<!--wodoc:unbalanced-end-->")
            | "div" ->
                Buffer.add_string out (Printf.sprintf "<div%s>" (attrs_of rest));
                stack := "</div>" :: !stack
            | "a" ->
                Buffer.add_string out (Printf.sprintf "<a%s>" (attrs_of rest));
                stack := "</a>" :: !stack
            | "span" ->
                Buffer.add_string out
                  (Printf.sprintf "<span%s>" (attrs_of rest));
                stack := "</span>" :: !stack
            | "img" ->
                Buffer.add_string out
                  (Printf.sprintf "<img%s/>" (attrs_of rest))
            | "@" ->
                Buffer.add_string out
                  (Printf.sprintf "<!--wodoc-attr:%s-->" rest)
            | "" -> ()
            | other ->
                Buffer.add_string out
                  (Printf.sprintf "<!--wodoc:unknown:%s-->" other));
            i := cend + String.length mclose)
  done;
  Buffer.contents out

(* Pass 2: <!--wodoc-attr:k=v-->: inject k=v into the next start tag, merging
   [class] with any existing one. Skips whitespace, </p>, <p>, comments. *)
let merge_attrs_into_tag tag extra =
  let attrs = parse_attrs (String.trim extra) in
  let cls =
    List.filter_map (fun (k, v) -> if k = "class" then Some v else None) attrs
  in
  let others = List.filter (fun (k, _) -> k <> "class") attrs in
  let extra_class = String.concat " " cls in
  let tag =
    if extra_class = ""
    then tag
    else if Str.string_match (Str.regexp ".*class=\"") tag 0
    then
      Str.replace_first
        (Str.regexp "class=\"\\([^\"]*\\)\"")
        (Printf.sprintf "class=\"\\1 %s\"" extra_class)
        tag
    else
      (* no existing class attribute: insert one before the closing '>' *)
      let close =
        if String.length tag >= 2 && tag.[String.length tag - 2] = '/'
        then 2
        else 1
      in
      String.sub tag 0 (String.length tag - close)
      ^ Printf.sprintf " class=\"%s\"" extra_class
      ^ String.sub tag (String.length tag - close) close
  in
  let oa = attrs_to_html others in
  if oa = ""
  then tag
  else
    let close =
      if String.length tag >= 2 && tag.[String.length tag - 2] = '/'
      then 2
      else 1
    in
    String.sub tag 0 (String.length tag - close)
    ^ oa
    ^ String.sub tag (String.length tag - close) close

let is_start_tag s p len =
  p < len && s.[p] = '<' && p + 1 < len && s.[p + 1] <> '/' && s.[p + 1] <> '!'

(* Skip whitespace and comments forward from [p]. When [skip_p] is true (only at
   the first level), also skip odoc's [<p>]/[</p>] wrappers so we reach the real
   construct. Returns the new position. *)
let skip_noise s len ~skip_p p =
  let p = ref p in
  let again = ref true in
  while !again && !p < len do
    let c = s.[!p] in
    if c = ' ' || c = '\n' || c = '\t' || c = '\r'
    then
      incr p
      (* skip_p consumes only the marker's own closing [</p>]; a following [<p>]
         is the target paragraph, not noise, so it is left in place. *)
    else if skip_p && !p + 4 <= len && String.sub s !p 4 = "</p>"
    then p := !p + 4
    else if !p + 4 <= len && String.sub s !p 4 = "<!--"
    then
      match find s "-->" !p with Some e -> p := e + 3 | None -> again := false
    else again := false
  done;
  !p

(* Read an HTML tag name ([A-Za-z0-9]+) starting at [p]. *)
let name_at s p len =
  let q = ref p in
  while
    !q < len
    &&
    let c = s.[!q] in
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
  do
    incr q
  done;
  String.sub s p (!q - p)

(* [p] is at a start tag [<name ...>]; return the position just after the
   element's matching close tag, accounting for nested elements of the same name
   (e.g. a table nested inside a cell). Self-closing tags end at their [>]. *)
let end_of_element s p len =
  match find s ">" p with
  | None -> len
  | Some gt0 ->
      if gt0 > p && s.[gt0 - 1] = '/'
      then gt0 + 1
      else begin
        let name = name_at s (p + 1) len in
        let depth = ref 1 and q = ref (gt0 + 1) in
        while !depth > 0 && !q < len do
          match find s "<" !q with
          | None -> q := len
          | Some lt -> (
              let close = lt + 1 < len && s.[lt + 1] = '/' in
              let nm = name_at s (lt + (if close then 2 else 1)) len in
              match find s ">" lt with
              | None -> q := len
              | Some gt ->
                  let selfclose = gt > lt && s.[gt - 1] = '/' in
                  if nm = name
                  then if close then decr depth else if not selfclose then incr depth;
                  q := gt + 1)
        done;
        !q
      end

(* Parse a section [N attrs] into its 1-based sibling index (default 1) and its
   attribute string. ["2 class=x"] -> [(2, "class=x")]; ["class=x"] -> [(1,
   "class=x")]; [""] -> [(1, "")]. *)
let parse_section sec =
  let n = String.length sec in
  let i = ref 0 in
  while !i < n && sec.[!i] >= '0' && sec.[!i] <= '9' do
    incr i
  done;
  if !i = 0
  then 1, sec
  else max 1 (int_of_string (String.sub sec 0 !i)), String.trim (Str.string_after sec !i)

(* A [<!--wodoc-attr:S0 | S1 | S2-->] sentinel applies section [Si] at nesting
   level [i], starting at the next real element after the sentinel. Each section
   is [[N] attrs]: descend to the first child at this level, skip [N-1] siblings
   to reach the [N]th (default the 1st), and merge [attrs] into it (a [class] is
   merged with any existing one). An empty attribute set styles nothing but still
   descends/selects. This mirrors html_of_wiki's [@@a@b@c@@] (e.g. table / row /
   cell), the index allowing any row or cell, not only the first. *)
let fuse_attrs s =
  let len = String.length s in
  let out = Buffer.create len in
  let asent = "<!--wodoc-attr:" in
  let alen = String.length asent in
  let copied = ref 0 in
  let i = ref 0 in
  while !i < len do
    match find s asent !i with
    | None -> i := len
    | Some start -> (
      match find s "-->" (start + alen) with
      | None -> i := len
      | Some cend ->
          (* copy up to the sentinel, then drop the sentinel itself *)
          Buffer.add_substring out s !copied (start - !copied);
          copied := cend + 3;
          let extra = String.sub s (start + alen) (cend - (start + alen)) in
          let sections =
            List.map String.trim (String.split_on_char '|' extra)
          in
          let pos = ref (cend + 3) in
          let stop = ref false in
          List.iteri
            (fun k section ->
               if not !stop
               then begin
                 let idx, attrs = parse_section section in
                 pos := skip_noise s len ~skip_p:(k = 0) !pos;
                 (* skip [idx - 1] complete siblings to reach the [idx]th *)
                 for _ = 2 to idx do
                   if (not !stop) && is_start_tag s !pos len
                   then pos := skip_noise s len ~skip_p:false (end_of_element s !pos len)
                   else stop := true
                 done;
                 if (not !stop) && is_start_tag s !pos len
                 then
                   match find s ">" !pos with
                   | Some gt ->
                       if attrs <> ""
                       then begin
                         Buffer.add_substring out s !copied (!pos - !copied);
                         let tag = String.sub s !pos (gt - !pos + 1) in
                         Buffer.add_string out (merge_attrs_into_tag tag attrs);
                         copied := gt + 1
                       end;
                       pos := gt + 1
                   | None -> stop := true
                 else stop := true
               end)
            sections;
          i := !pos)
  done;
  Buffer.add_substring out s !copied (len - !copied);
  Buffer.contents out

(* Pass 3: hoist structural tags out of odoc's forced <p> wrappers. *)
let lead_re =
  Str.regexp
    "^[ \t\r\n]*\\(</?\\(div\\|a\\|span\\)\\b[^>]*>\\|<img\\b[^>]*/?>\\)"

let tail_re =
  Str.regexp
    "\\(</?\\(div\\|a\\|span\\)\\b[^>]*>\\|<img\\b[^>]*/?>\\)[ \t\r\n]*$"

let contains s sub = find s sub 0 <> None
let is_close g = String.length g >= 2 && g.[1] = '/'
let is_img g = String.length g >= 4 && String.sub g 0 4 = "<img"

(* Hoist only UNBALANCED structural tags out of the paragraph: an opening tag
   whose close is not also inside (a container spanning paragraphs), or a closing
   tag whose open is elsewhere. A balanced inline element (e.g. a link
   [<a>text</a>] or [<a><img/></a>]) is left untouched inside the paragraph. *)
let split_paragraph inner =
  let lead = Buffer.create 16 in
  let tail = ref "" in
  let mid = ref inner in
  let again = ref true in
  while !again do
    again := false;
    if Str.string_match lead_re !mid 0
    then begin
      let g = Str.matched_group 1 !mid in
      let rest = Str.string_after !mid (Str.match_end ()) in
      let peel () =
        Buffer.add_string lead g;
        mid := rest;
        again := true
      in
      if is_img g || is_close g
      then peel ()
      else
        let name = Str.matched_group 2 !mid in
        if not (contains rest ("</" ^ name ^ ">")) then peel ()
    end
  done;
  again := true;
  while !again do
    again := false;
    try
      let _ = Str.search_forward tail_re !mid 0 in
      if Str.match_end () = String.length !mid
      then begin
        let g = Str.matched_group 1 !mid in
        let before = String.sub !mid 0 (Str.match_beginning ()) in
        let peel () =
          tail := g ^ !tail;
          mid := before;
          again := true
        in
        if is_img g || not (is_close g)
        then peel ()
        else
          let name = Str.matched_group 2 !mid in
          if not (contains before ("<" ^ name)) then peel ()
      end
    with Not_found -> ()
  done;
  Buffer.contents lead, String.trim !mid, !tail

let hoist s =
  let out = Buffer.create (String.length s) in
  let len = String.length s in
  let i = ref 0 in
  while !i < len do
    match find s "<p>" !i with
    | None ->
        Buffer.add_substring out s !i (len - !i);
        i := len
    | Some p -> (
      match find s "</p>" (p + 3) with
      | None ->
          Buffer.add_substring out s !i (len - !i);
          i := len
      | Some q ->
          let inner = String.sub s (p + 3) (q - (p + 3)) in
          Buffer.add_substring out s !i (p - !i);
          let lead, mid, tail = split_paragraph inner in
          Buffer.add_string out lead;
          if mid <> ""
          then (
            Buffer.add_string out "<p>";
            Buffer.add_string out mid;
            Buffer.add_string out "</p>");
          Buffer.add_string out tail;
          i := q + 4)
  done;
  Buffer.contents out

(* odoc adds an empty [<a href="#id" class="anchor"></a>] inside every heading
   for hover-to-link. On website pages this both differs from the site style and,
   inside a clickable card, would nest an <a> in an <a>. Optionally drop them. *)
let strip_heading_anchors s =
  Str.global_replace
    (Str.regexp "<a href=\"#[^\"]*\" class=\"anchor\">[^<]*</a>")
    "" s

let html ?(strip_anchors = false) s =
  let s = s |> emit_tags |> fuse_attrs |> hoist in
  if strip_anchors then strip_heading_anchors s else s
