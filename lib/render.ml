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

(* "key=val key2=val2" -> " key=\"val\" key2=\"val2\"" *)
let attrs_of toks =
  let b = Buffer.create 32 in
  List.iter
    (fun t ->
       match String.index_opt t '=' with
       | Some i ->
           let k = String.sub t 0 i in
           let v = String.sub t (i + 1) (String.length t - i - 1) in
           Buffer.add_string b (Printf.sprintf " %s=\"%s\"" k v)
       | None -> ())
    toks;
  Buffer.contents b

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
            let toks = String.split_on_char ' ' d in
            (match toks with
            | "end" :: _ -> (
              match !stack with
              | t :: tl ->
                  Buffer.add_string out t;
                  stack := tl
              | [] -> Buffer.add_string out "<!--wodoc:unbalanced-end-->")
            | "div" :: r ->
                Buffer.add_string out (Printf.sprintf "<div%s>" (attrs_of r));
                stack := "</div>" :: !stack
            | "a" :: r ->
                Buffer.add_string out (Printf.sprintf "<a%s>" (attrs_of r));
                stack := "</a>" :: !stack
            | "span" :: r ->
                Buffer.add_string out (Printf.sprintf "<span%s>" (attrs_of r));
                stack := "</span>" :: !stack
            | "img" :: r ->
                Buffer.add_string out (Printf.sprintf "<img%s/>" (attrs_of r))
            | "@" :: r ->
                Buffer.add_string out
                  (Printf.sprintf "<!--wodoc-attr:%s-->" (String.concat " " r))
            | other :: _ ->
                Buffer.add_string out
                  (Printf.sprintf "<!--wodoc:unknown:%s-->" other)
            | [] -> ());
            i := cend + String.length mclose)
  done;
  Buffer.contents out

(* Pass 2: <!--wodoc-attr:k=v-->: inject k=v into the next start tag, merging
   [class] with any existing one. Skips whitespace, </p>, <p>, comments. *)
let merge_attrs_into_tag tag extra =
  let toks = String.split_on_char ' ' (String.trim extra) in
  let is_class t =
    match String.index_opt t '=' with
    | Some i -> String.sub t 0 i = "class"
    | None -> false
  in
  let cls =
    List.filter_map
      (fun t ->
         match String.index_opt t '=' with
         | Some i when String.sub t 0 i = "class" ->
             Some (String.sub t (i + 1) (String.length t - i - 1))
         | _ -> None)
      toks
  in
  let others =
    List.filter (fun t -> (not (is_class t)) && String.contains t '=') toks
  in
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
  let oa = attrs_of others in
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

let fuse_attrs s =
  let out = Buffer.create (String.length s) in
  let len = String.length s in
  let i = ref 0 in
  let asent = "<!--wodoc-attr:" in
  while !i < len do
    match find s asent !i with
    | None ->
        Buffer.add_substring out s !i (len - !i);
        i := len
    | Some start -> (
        Buffer.add_substring out s !i (start - !i);
        match find s "-->" (start + String.length asent) with
        | None ->
            Buffer.add_substring out s start (len - start);
            i := len
        | Some cend -> (
            let extra =
              String.sub s
                (start + String.length asent)
                (cend - (start + String.length asent))
            in
            let j = ref (cend + 3) in
            let skip = ref true in
            while !skip && !j < len do
              let c = s.[!j] in
              if c = ' ' || c = '\n' || c = '\t' || c = '\r'
              then incr j
              else if !j + 4 <= len && String.sub s !j 4 = "</p>"
              then j := !j + 4
              else if !j + 3 <= len && String.sub s !j 3 = "<p>"
              then j := !j + 3
              else if !j + 4 <= len && String.sub s !j 4 = "<!--"
              then
                match find s "-->" !j with
                | Some e -> j := e + 3
                | None -> skip := false
              else skip := false
            done;
            Buffer.add_substring out s (cend + 3) (!j - (cend + 3));
            match find s ">" !j with
            | Some gt ->
                let tag = String.sub s !j (gt - !j + 1) in
                Buffer.add_string out (merge_attrs_into_tag tag extra);
                i := gt + 1
            | None -> i := !j))
  done;
  Buffer.contents out

(* Pass 3: hoist structural tags out of odoc's forced <p> wrappers. *)
let lead_re =
  Str.regexp
    "^[ \t\r\n]*\\(</?\\(div\\|a\\|span\\)\\b[^>]*>\\|<img\\b[^>]*/?>\\)"

let tail_re =
  Str.regexp
    "\\(</?\\(div\\|a\\|span\\)\\b[^>]*>\\|<img\\b[^>]*/?>\\)[ \t\r\n]*$"

let split_paragraph inner =
  let lead = Buffer.create 16 in
  let tail = ref "" in
  let mid = ref inner in
  let again = ref true in
  while !again do
    again := false;
    if Str.string_match lead_re !mid 0
    then (
      Buffer.add_string lead (Str.matched_group 1 !mid);
      mid := Str.string_after !mid (Str.match_end ());
      again := true);
    try
      let _ = Str.search_forward tail_re !mid 0 in
      if Str.match_end () = String.length !mid
      then (
        let g = Str.matched_group 1 !mid in
        let b = Str.match_beginning () in
        tail := g ^ !tail;
        mid := String.sub !mid 0 b;
        again := true)
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

let html s = s |> emit_tags |> fuse_attrs |> hoist
