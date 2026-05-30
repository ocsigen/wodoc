(* Best-effort wikicréole -> odoc .mld converter. Staged string rewrites:
   A. protect {{{...}}} code/verbatim
   B. << name args | ... >> wrappers (stack) + <<|...>> comments
   C. line-start headings and lists
   D. inline: links, images, @@attrs, bold/italic/monospace, line breaks
   E. restore code.
   It is a migration aid; output is expected to be reviewed by hand. *)

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

let starts_with p s =
  String.length s >= String.length p && String.sub s 0 (String.length p) = p

let replace_once s ph repl =
  match find s ph 0 with
  | None -> s
  | Some p ->
      String.sub s 0 p ^ repl
      ^ String.sub s
          (p + String.length ph)
          (String.length s - p - String.length ph)

(* ---- A. protect code ---- *)
let code_lang opener =
  match
    Str.search_forward
      (Str.regexp "language=[\"']\\([a-zA-Z0-9_-]+\\)[\"']")
      opener 0
  with
  | exception Not_found -> ""
  | _ -> Str.matched_group 1 opener

let verbatim_repl inner =
  if String.contains inner '\n'
  then "{v" ^ inner ^ "v}" (* plain preformatted block *)
  else "[" ^ String.trim inner ^ "]" (* inline code *)

(* a class on a code block (e.g. server/client/shared for Eliom) is kept as a
   wodoc attribute marker on the resulting <pre>, so the side colouring applies
   on the themed site and is dropped on stock odoc. *)
let code_class opener =
  match
    Str.search_forward
      (Str.regexp "class=[\"']\\([a-zA-Z0-9_ -]+\\)[\"']")
      opener 0
  with
  | exception Not_found -> ""
  | _ -> Str.matched_group 1 opener

let code_repl ?(cls = "") lang inner =
  let block =
    if lang = ""
    then "{[" ^ inner ^ "]}"
    else Printf.sprintf "{@%s[%s]}" lang inner
  in
  if cls = ""
  then block
  else Printf.sprintf "{%%wodoc:@ class=%s%%}\n%s" cls block

(* Protect both {{{...}}} (verbatim) and <<code lang|...>> (highlighted code):
   their bodies must not go through the inline/wrapper passes. *)
let protect_code s =
  let n = String.length s in
  let buf = Buffer.create n in
  let store = ref [] in
  let idx = ref 0 in
  let stash repl =
    let ph = Printf.sprintf "\000C%d\000" !idx in
    store := (ph, repl) :: !store;
    incr idx;
    Buffer.add_string buf ph
  in
  let i = ref 0 in
  while !i < n do
    if !i + 3 <= n && String.sub s !i 3 = "{{{"
    then (
      match find s "}}}" (!i + 3) with
      | Some e ->
          stash (verbatim_repl (String.sub s (!i + 3) (e - (!i + 3))));
          i := e + 3
      | None ->
          Buffer.add_char buf s.[!i];
          incr i)
    else if !i + 6 <= n && String.sub s !i 6 = "<<code"
    then (
      match find s "|" (!i + 6) with
      | Some p -> (
        match find s ">>" (p + 1) with
        | Some e ->
            let opener = String.sub s (!i + 6) (p - (!i + 6)) in
            let lang = code_lang opener and cls = code_class opener in
            stash (code_repl ~cls lang (String.sub s (p + 1) (e - (p + 1))));
            i := e + 2
        | None ->
            Buffer.add_char buf s.[!i];
            incr i)
      | None ->
          Buffer.add_char buf s.[!i];
          incr i)
    else begin
      Buffer.add_char buf s.[!i];
      incr i
    end
  done;
  Buffer.contents buf, !store

let restore_code s store =
  List.fold_left (fun acc (ph, repl) -> replace_once acc ph repl) s store

(* ---- B. << ... >> wrappers ---- *)
(* parse a class="..." attribute out of an opener's argument string *)
let class_attr args =
  match Str.search_forward (Str.regexp "class=\"\\([^\"]*\\)\"") args 0 with
  | exception Not_found -> ""
  | _ -> Printf.sprintf " class=\"%s\"" (Str.matched_group 1 args)

(* read a name="value" attribute out of an opener's argument string *)
let attr_val name args =
  match Str.search_forward (Str.regexp (name ^ "=\"\\([^\"]*\\)\"")) args 0 with
  | exception Not_found -> None
  | _ -> Some (Str.matched_group 1 args)

(* "module Cors" / "val Ocsigen.Server.start" -> "Cors" / "Ocsigen.Server.start":
   drop a leading kind keyword (module/val/type/class/...), keep the path. *)
let api_target body =
  let body = String.trim body in
  if Str.string_match (Str.regexp "^[a-z]+[ \t]+\\(.+\\)$") body 0
  then String.trim (Str.matched_group 1 body)
  else body

(* <<a_api [text="..."]|module M>> -> {!M} or {{!M}text} *)
let a_api_ref opener body =
  let target = api_target body in
  match attr_val "text" opener with
  | Some t -> Printf.sprintf "{{!%s}%s}" target t
  | None -> Printf.sprintf "{!%s}" target

(* <<a_manual chapter="c" [fragment="f"]|text>> -> {{!page-c}text} / {{!page-c.f}text} *)
let a_manual_ref opener body =
  let text = String.trim body in
  let page = Option.value ~default:"" (attr_val "chapter" opener) in
  let target =
    match attr_val "fragment" opener with
    | Some f -> Printf.sprintf "page-%s.%s" page f
    | None -> Printf.sprintf "page-%s" page
  in
  Printf.sprintf "{{!%s}%s}" target text

type closer = Close of string | Drop

let wrappers s =
  let n = String.length s in
  let buf = Buffer.create n in
  let stack = ref [] in
  let drop = ref 0 in
  let emit str = if !drop = 0 then Buffer.add_string buf str in
  let emit_char c = if !drop = 0 then Buffer.add_char buf c in
  let i = ref 0 in
  while !i < n do
    if !i + 2 <= n && s.[!i] = '<' && s.[!i + 1] = '<'
    then begin
      (* find first of '|' or '>>' after the "<<" *)
      let pipe = find s "|" (!i + 2) in
      let close = find s ">>" (!i + 2) in
      let body_sep =
        match pipe, close with
        | Some p, Some c -> if p < c then `Pipe p else `NoBody c
        | Some p, None -> `Pipe p
        | None, Some c -> `NoBody c
        | None, None -> `None
      in
      match body_sep with
      | `None ->
          emit_char s.[!i];
          incr i
      | `NoBody c ->
          (* <<ext>> with no body: drop (menu/version/etc. are not content) *)
          i := c + 2
      | `Pipe p ->
          let opener = String.trim (String.sub s (!i + 2) (p - (!i + 2))) in
          if starts_with "a_api" opener || starts_with "a_manual" opener
          then (
            (* inline cross-reference: consume through the matching >> and emit
               an odoc reference (no entry on the wrapper stack) *)
            match find s ">>" (p + 1) with
            | Some e ->
                let body = String.sub s (p + 1) (e - (p + 1)) in
                emit
                  (if starts_with "a_api" opener
                   then a_api_ref opener body
                   else a_manual_ref opener body);
                i := e + 2
            | None ->
                emit_char s.[!i];
                incr i)
          else begin
            if opener = ""
            then (
              (* <<|  comment: drop until matching >> *)
              stack := Drop :: !stack;
              incr drop)
            else if starts_with "header" opener
            then stack := Close "" :: !stack
            else if starts_with "div" opener
            then (
              emit (Printf.sprintf "{%%wodoc:div%s%%}" (class_attr opener));
              stack := Close "{%wodoc:end%}" :: !stack)
            else if starts_with "span" opener
            then (
              emit (Printf.sprintf "{%%wodoc:span%s%%}" (class_attr opener));
              stack := Close "{%wodoc:end%}" :: !stack)
            else if
              starts_with "head-css" opener || starts_with "head-script" opener
            then (
              stack := Drop :: !stack;
              incr drop)
            else (
              (* unknown wrapper: keep its body, mark for review *)
              emit (Printf.sprintf "{%%wodoc:%s%%}" opener);
              stack := Close "{%wodoc:end%}" :: !stack);
            i := p + 1
          end
    end
    else if !i + 2 <= n && s.[!i] = '>' && s.[!i + 1] = '>'
    then begin
      (match !stack with
      | Drop :: tl ->
          stack := tl;
          decr drop
      | Close c :: tl ->
          stack := tl;
          emit c
      | [] -> ());
      i := !i + 2
    end
    else begin
      emit_char s.[!i];
      incr i
    end
  done;
  Buffer.contents buf

(* ---- C. headings and lists (line-based) ---- *)
let heading_re = Str.regexp "^[ \t]*\\(=+\\)[ \t]*\\(.*\\)$"
let item_re = Str.regexp "^[ \t]*\\([*#]+\\)[ \t]+\\(.*\\)$"

let rstrip_eq s =
  let n = ref (String.length s) in
  while !n > 0 && (s.[!n - 1] = '=' || s.[!n - 1] = ' ' || s.[!n - 1] = '\t') do
    decr n
  done;
  String.sub s 0 !n

(* A leading anchor on a heading, e.g. @@id="upload"@@ or @@id='upload' (no
   closing @@): becomes an odoc heading label so cross-page fragment references
   ({{!page-x.upload}..}) resolve. Returns (label option, remaining text). *)
let heading_label_re = Str.regexp "^@@id=[\"']\\([^\"']+\\)[\"']\\(@@\\)?[ \t]*"

let split_heading_label text =
  if Str.string_match heading_label_re text 0
  then Some (Str.matched_group 1 text), Str.string_after text (Str.match_end ())
  else None, text

(* An odoc page has a single level-0 title. Classify lines first, then enforce
   exactly one {0}: if a title exists, keep the first and demote later level-0
   headings to {1}; if none exists, promote the first heading to the title. *)
let lines_pass s =
  let parsed =
    String.split_on_char '\n' s
    |> List.map (fun line ->
      if Str.string_match heading_re line 0
      then
        let level = max 0 (String.length (Str.matched_group 1 line) - 1) in
        let label, text =
          split_heading_label (rstrip_eq (Str.matched_group 2 line))
        in
        `Heading (level, label, text)
      else if Str.string_match item_re line 0
      then
        let marks = Str.matched_group 1 line in
        let text = Str.matched_group 2 line in
        let bullet =
          if marks.[String.length marks - 1] = '#' then "+" else "-"
        in
        `Line (Printf.sprintf "%s %s" bullet text)
      else `Line line)
  in
  let has_title =
    List.exists (function `Heading (0, _, _) -> true | _ -> false) parsed
  in
  let title_used = ref false and promoted = ref false in
  let level_of orig =
    if has_title
    then
      if orig = 0 && not !title_used
      then (
        title_used := true;
        0)
      else if orig = 0
      then 1 (* demote a second top-level heading *)
      else orig
    else if not !promoted
    then (
      promoted := true;
      0 (* no explicit title: the first heading becomes the page title *))
    else orig
  in
  parsed
  |> List.map (function
    | `Line l -> l
    | `Heading (level, label, text) ->
        let anchor = match label with Some l -> ":" ^ l | None -> "" in
        Printf.sprintf "{%d%s %s}" (level_of level) anchor text)
  |> String.concat "\n"

(* ---- D. inline ---- *)
let deabbrev url =
  if starts_with "wiki(" url
  then
    match
      Str.search_forward (Str.regexp "^wiki(\"\\([^\"]+\\)\"):\\(.*\\)$") url 0
    with
    | exception Not_found -> url
    | _ ->
        let w = Str.matched_group 1 url and p = Str.matched_group 2 url in
        "../" ^ w ^ "/" ^ p
  else if starts_with "site:/" url
  then "../" ^ String.sub url 6 (String.length url - 6)
  else if starts_with "site:" url
  then "../" ^ String.sub url 5 (String.length url - 5)
  else url

(* extract [[...]] links and {{...}} images into placeholders (already converted
   to mld), so later inline passes don't touch their URLs *)
let protect_links s =
  let n = String.length s in
  let buf = Buffer.create n in
  let store = ref [] in
  let idx = ref 0 in
  let stash repl =
    let ph = Printf.sprintf "\000L%d\000" !idx in
    store := (ph, repl) :: !store;
    incr idx;
    Buffer.add_string buf ph
  in
  let i = ref 0 in
  while !i < n do
    if !i + 2 <= n && s.[!i] = '[' && s.[!i + 1] = '['
    then (
      match find s "]]" (!i + 2) with
      | Some e ->
          let inner = String.sub s (!i + 2) (e - (!i + 2)) in
          let url, text =
            match String.index_opt inner '|' with
            | Some b ->
                ( String.sub inner 0 b
                , String.sub inner (b + 1) (String.length inner - b - 1) )
            | None -> inner, inner
          in
          stash (Printf.sprintf "{{:%s}%s}" (deabbrev (String.trim url)) text);
          i := e + 2
      | None ->
          Buffer.add_char buf s.[!i];
          incr i)
    else if
      !i + 2 <= n
      && s.[!i] = '{'
      && s.[!i + 1] = '{'
      && (!i + 2 >= n || s.[!i + 2] <> '!')
      (* a double-brace followed by '!' is an odoc reference (e.g. emitted by
         a_api/a_manual), not a wiki image; leave it untouched. *)
    then (
      match find s "}}" (!i + 2) with
      | Some e ->
          let inner = String.sub s (!i + 2) (e - (!i + 2)) in
          (* optional leading @@class="..."@@ *)
          let cls, inner =
            match
              Str.search_forward
                (Str.regexp "^@@class=\"\\([^\"]*\\)\"@@")
                inner 0
            with
            | exception Not_found -> "", inner
            | _ ->
                ( Printf.sprintf " class=\"%s\"" (Str.matched_group 1 inner)
                , Str.string_after inner (Str.match_end ()) )
          in
          let url, alt =
            match String.index_opt inner '|' with
            | Some b ->
                ( String.sub inner 0 b
                , String.sub inner (b + 1) (String.length inner - b - 1) )
            | None -> inner, ""
          in
          stash
            (Printf.sprintf "{%%wodoc:img%s src=\"%s\" alt=\"%s\"%%}" cls
               (deabbrev (String.trim url))
               (String.trim alt));
          i := e + 2
      | None ->
          Buffer.add_char buf s.[!i];
          incr i)
    else begin
      Buffer.add_char buf s.[!i];
      incr i
    end
  done;
  Buffer.contents buf, !store

let restore_links s store =
  List.fold_left (fun acc (ph, repl) -> replace_once acc ph repl) s store

(* toggle a paired marker [mk] into [op]/[cl] *)
let toggle s mk op cl =
  let n = String.length s and ml = String.length mk in
  let buf = Buffer.create n in
  let i = ref 0 and opened = ref false in
  while !i < n do
    if !i + ml <= n && String.sub s !i ml = mk
    then (
      Buffer.add_string buf (if !opened then cl else op);
      opened := not !opened;
      i := !i + ml)
    else begin
      Buffer.add_char buf s.[!i];
      incr i
    end
  done;
  Buffer.contents buf

(* @@class="a"@b@c@@ -> {%wodoc:@ class="a" | b | c%} *)
let attrs_pass s =
  Str.global_substitute
    (Str.regexp "@@\\([^@]*\\(@[^@]*\\)*\\)@@")
    (fun m ->
       let inner = Str.matched_group 1 m in
       let sections = String.split_on_char '@' inner |> List.map String.trim in
       Printf.sprintf "{%%wodoc:@ %s%%}" (String.concat " | " sections))
    s

let inline s =
  let s, links = protect_links s in
  let s = attrs_pass s in
  let s = toggle s "**" "{b " "}" in
  let s = toggle s "//" "{e " "}" in
  let s = toggle s "##" "[" "]" in
  let s = Str.global_replace (Str.regexp_string "\\\\") "{%html:<br/>%}" s in
  restore_links s links

let wiki_to_mld s =
  let s, code = protect_code s in
  let s = wrappers s in
  let s = lines_pass s in
  let s = inline s in
  let s = restore_code s code in
  s
