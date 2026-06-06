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

(* In wikicreole [~] escapes the next markup, so [~>>] / [~<<] are a literal
   [>>] / [<<] inside a code block — used so OCaml [>>=] (Lwt bind) and camlp4
   [<:table< … >>] quotations don't close the [<<code …>>] block. Find the
   closing [>>] = the first one NOT escaped by a preceding [~]. *)
let find_code_close s from =
  let rec go i =
    match find s ">>" i with
    | None -> None
    | Some k -> if k > 0 && s.[k - 1] = '~' then go (k + 2) else Some k
  in
  go from

(* Drop the [~] from an escaped [~>>] / [~<<] in a (verbatim) code body, so the
   rendered code shows the real [>>] / [<<]. Other [~] (labelled arguments like
   [~service]) are left untouched. *)
let unescape_code s =
  let s = Str.global_replace (Str.regexp_string "~>>") ">>" s in
  Str.global_replace (Str.regexp_string "~<<") "<<" s

(* Remove [<<|...>>] comments BEFORE anything else, exactly as html_of_wiki
   does: a comment is opaque and closes at the FIRST [>>], so its body (even a
   nested [<<code…>>] example, an [<<a_manual…>>], or text) is dropped wholesale
   without being parsed. Doing this before protect_code matters: otherwise
   protect_code would grab a [<<code…>>] that lives inside a comment and consume
   the very [>>] that closes the comment, making the comment overrun into real
   content that follows (a section heading). *)
let strip_comments s =
  let n = String.length s in
  let buf = Buffer.create n in
  let i = ref 0 in
  while !i < n do
    if !i + 3 <= n && s.[!i] = '<' && s.[!i + 1] = '<' && s.[!i + 2] = '|'
    then
      (* close at the first UNescaped >> (a ~>> is a literal >>, e.g. >>= in a
         commented-out code example, and does not close the comment). *)
      i := (match find_code_close s (!i + 3) with Some e -> e + 2 | None -> n)
    else (
      Buffer.add_char buf s.[!i];
      incr i)
  done;
  Buffer.contents buf

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
        match find_code_close s (p + 1) with
        | Some e ->
            let opener = String.sub s (!i + 6) (p - (!i + 6)) in
            let lang = code_lang opener and cls = code_class opener in
            let body = unescape_code (String.sub s (p + 1) (e - (p + 1))) in
            stash (code_repl ~cls lang body);
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

(* read a name="value" attribute out of an opener's argument string. The name
   must be on a word boundary so that "project" does not match "subproject". *)
let attr_val name args =
  match
    Str.search_forward
      (Str.regexp
         (Printf.sprintf "\\(^\\|[^a-zA-Z_]\\)%s=\"\\([^\"]*\\)\"" name))
      args 0
  with
  | exception Not_found -> None
  | _ -> Some (Str.matched_group 2 args)

(* Split an API target into its kind keyword and qualified name:
   "module Cors" -> ("module", "Cors"); "val Eliom.Service.start" ->
   ("val", "Eliom.Service.start"). With no keyword, assume a module. *)
let api_kind_and_name body =
  let body = String.trim body in
  if Str.string_match (Str.regexp "^\\([a-z]+\\)[ \t]+\\(.+\\)$") body 0
  then Str.matched_group 1 body, String.trim (Str.matched_group 2 body)
  else "module", body

(* The page path and in-page anchor for an API target. A module is a page of its
   own; a val/type/exception/… lives on its parent module's page under an odoc
   anchor (#val-x / #type-x / …). *)
let api_path_anchor kind name =
  let comps = String.split_on_char '.' name in
  let module_page () = String.concat "/" comps, "" in
  let member prefix =
    match List.rev comps with
    | last :: rev_mod ->
        ( String.concat "/" (List.rev rev_mod)
        , Printf.sprintf "#%s-%s" prefix last )
    | [] -> module_page ()
  in
  match kind with
  | "val" | "value" | "method" -> member "val"
  | "type" -> member "type"
  | "exception" -> member "exception"
  | _ -> module_page ()

(* <<a_api [project=P] [subproject=S] [text=T]|KIND M>>.
   Without project/subproject (and no [default_side]): an odoc reference {!M}
   (resolves in-package, e.g. on ocaml.org). With a side or project, a direct
   link into the themed wodoc tree so it is clickable even from a standalone
   manual build:
   - side server|client (this project) -> ../eliom.<side>/<path>/index.html[#a]
   - project=P (another Ocsigen project) -> /wodoc/<P>/latest/<path>/index.html[#a]
   [default_side] makes a plain <<a_api|...>> behave as that side (the manual's
   bare references are server-side). Links to other projects may 404 until their
   doc is deployed — an intentional, visible reminder rather than a dropped link.
   URL links are emitted as wikicreole [[url|text]] so the later inline pass
   protects them (a raw "https://" would otherwise be mangled by // -> emphasis). *)
let a_api_ref ?(default_side = "") ?(odoc_refs = false) opener body =
  let kind, name = api_kind_and_name body in
  let text = Option.value ~default:name (attr_val "text" opener) in
  let path, anchor = api_path_anchor kind name in
  let project = attr_val "project" opener in
  let side =
    match attr_val "subproject" opener with
    | Some s -> Some s
    | None ->
        if project = None && default_side <> "" then Some default_side else None
  in
  (* odoc_refs: emit a native reference {!Name} (resolves same-side in-library and
     cross-package via odoc) — used when the manual is built in the same odoc
     run as the API (unified in-package build). project/subproject are dropped:
     the qualified name suffices. *)
  if odoc_refs
  then
    match attr_val "text" opener with
    | Some t -> Printf.sprintf "{{!%s}%s}" name t
    | None -> Printf.sprintf "{!%s}" name
  else
    match project, side with
    | Some proj, _ when proj <> "eliom" ->
        Printf.sprintf
          "[[https://ocsigen.org/wodoc/%s/latest/%s/index.html%s|%s]]" proj path
          anchor text
    | _, Some side ->
        Printf.sprintf "[[../eliom.%s/%s/index.html%s|%s]]" side path anchor
          text
    | _ -> (
      match attr_val "text" opener with
      | Some t -> Printf.sprintf "{{!%s}%s}" name t
      | None -> Printf.sprintf "{!%s}" name)

(* <<a_manual [project=P] chapter="c" [fragment="f"]|text>> -> a relative link to
   the sibling manual page (c.html[#f]), or to another project's manual for
   [project=P]. Relative links are robust (hyphenated chapters, section anchors,
   same-side) and keep working on both ocaml.org and ocsigen.org, where manual
   pages are siblings. Emitted as wikicreole [[url|text]] so the inline pass
   protects the URL. *)
let a_manual_ref ?(odoc_refs = false) opener body =
  let text = String.trim body in
  let page = Option.value ~default:"" (attr_val "chapter" opener) in
  let frag = attr_val "fragment" opener in
  let anchor = match frag with Some f -> "#" ^ f | None -> "" in
  match attr_val "project" opener with
  | Some proj ->
      (* another project's manual page: a RELATIVE link to the sibling project,
         correct on the final flat ocsigen.org/<proj>/ layout and on ocaml.org
         where manuals are siblings (report piège #10 — never absolute for
         content). *)
      Printf.sprintf "[[../%s/%s.html%s|%s]]" proj page anchor text
  | None when odoc_refs ->
      (* in-package build: an odoc page reference (resolves in the same run) *)
      let target =
        match frag with
        | Some f -> Printf.sprintf "page-\"%s\".%s" page f
        | None -> Printf.sprintf "page-\"%s\"" page
      in
      Printf.sprintf "{{!%s}%s}" target text
  | None -> Printf.sprintf "[[%s.html%s|%s]]" page anchor text

(* <<a_file src="path"|text>> -> a link to a downloadable asset shipped under
   files/ (the manual's assets directory). *)
let a_file_ref opener body =
  let src = Option.value ~default:"" (attr_val "src" opener) in
  Printf.sprintf "[[files/%s|%s]]" src (String.trim body)

type closer = Close of string | Drop

let wrappers ?(default_side = "") ?(odoc_refs = false) s =
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
          if opener = ""
          then
            (* <<|...>> comment: skip to the first >> (opaque). Comments are
               normally already removed by strip_comments (a pre-pass run before
               protect_code, matching html_of_wiki's first->> closing); this is
               a fallback for any comment that survived. *)
            i := (match find s ">>" (p + 1) with Some e -> e + 2 | None -> n)
          else if
            starts_with "a_api" opener || starts_with "a_manual" opener
            || starts_with "a_file" opener
          then (
            (* inline cross-reference: consume through the matching >> and emit
               an odoc reference / link (no entry on the wrapper stack) *)
            match find s ">>" (p + 1) with
            | Some e ->
                let body = String.sub s (p + 1) (e - (p + 1)) in
                emit
                  (if starts_with "a_api" opener
                   then a_api_ref ~default_side ~odoc_refs opener body
                   else if starts_with "a_file" opener
                   then a_file_ref opener body
                   else a_manual_ref ~odoc_refs opener body);
                i := e + 2
            | None ->
                emit_char s.[!i];
                incr i)
          else begin
            if starts_with "header" opener
            then (
              (* <<header|==X==>> wraps a section heading; reproduce the <header>
                 element html_of_wiki emits, so e.g. section.docblock > header
                 CSS (sticky title) applies. Newlines around the body keep the
                 inner ==X== on its own line so it still becomes a heading. *)
              emit "{%wodoc:header%}\n";
              stack := Close "\n{%wodoc:end%}" :: !stack)
            else if starts_with "webonly" opener
            then
              (* <<webonly|..>> shows its body on the web (which is us): keep the
                 body, drop the wrapper. *)
              stack := Close "" :: !stack
            else if starts_with "div" opener
            then (
              emit (Printf.sprintf "{%%wodoc:div%s%%}" (class_attr opener));
              stack := Close "{%wodoc:end%}" :: !stack)
            else if starts_with "span" opener
            then (
              emit (Printf.sprintf "{%%wodoc:span%s%%}" (class_attr opener));
              stack := Close "{%wodoc:end%}" :: !stack)
            else if
              starts_with "head-css" opener
              || starts_with "head-script" opener
              (* odoc builds its own page TOC, so the manual TOC directive and
                 its placeholder body are dropped *)
              || starts_with "outline" opener
            then (
              stack := Drop :: !stack;
              incr drop)
            else if starts_with "wip" opener
            then (
              (* "work in progress" note: html_of_wiki renders <aside
                 class="wip"><h5>Work in progress</h5>…; mirror the element and
                 its auto-header so the existing CSS applies. *)
              emit "{%wodoc:aside class=\"wip\"%}{b Work in progress}\n\n";
              stack := Close "{%wodoc:end%}" :: !stack)
            else if starts_with "paragraph" opener
            then (
              (* block note: a div carrying the wrapper's name as class *)
              emit "{%wodoc:div class=\"paragraph\"%}";
              stack := Close "{%wodoc:end%}" :: !stack)
            else if starts_with "concepts" opener
            then (
              (* the "Concepts" summary box (plural): listed upcoming concepts,
                 rendered <aside class="concepts"> with an auto "Concepts"
                 header. Check BEFORE the singular "concept" (a prefix of it). *)
              emit "{%wodoc:aside class=\"concepts\"%}{b Concepts}\n\n";
              stack := Close "{%wodoc:end%}" :: !stack)
            else if starts_with "concept" opener
            then (
              (* a "Concept: <title>" callout box (singular), <aside
                 class="concept">. *)
              emit "{%wodoc:aside class=\"concept\"%}";
              (match attr_val "title" opener with
              | Some t when t <> "" ->
                  emit (Printf.sprintf "{b Concept: %s}\n\n" t)
              | _ -> emit "{b Concept}\n\n");
              stack := Close "{%wodoc:end%}" :: !stack)
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
let heading_label_re =
  Str.regexp "^@@[Ii][Dd]=[\"']\\([^\"']+\\)[\"']\\(@@\\)?[ \t]*"

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
(* A bare wiki page reference ([[basics-server|…]], or the page part of a
   [wiki("w"):page] inter-project link) names a manual page, which is published
   as <page>.html. Append the extension, preserving a trailing #anchor, unless
   the reference already looks like a URL/anchor/path/file (scheme, '/', '#',
   '.', leading '#'). *)
let add_html_ext p =
  let page, anchor =
    match String.index_opt p '#' with
    | Some k -> String.sub p 0 k, String.sub p k (String.length p - k)
    | None -> p, ""
  in
  if
    page = "" || String.contains page ':' || String.contains page '/'
    || String.contains page '.'
  then p
  else page ^ ".html" ^ anchor

let deabbrev url =
  if starts_with "wiki(" url
  then
    match
      Str.search_forward (Str.regexp "^wiki(\"\\([^\"]+\\)\"):\\(.*\\)$") url 0
    with
    | exception Not_found -> url
    | _ ->
        let w = Str.matched_group 1 url and p = Str.matched_group 2 url in
        "../" ^ w ^ "/" ^ add_html_ext p
  else if starts_with "site:/" url
  then "../" ^ String.sub url 6 (String.length url - 6)
  else if starts_with "site:" url
  then "../" ^ String.sub url 5 (String.length url - 5)
  else if String.contains url ':' || (String.length url > 0 && url.[0] = '#')
  then url (* a scheme URL (http:, mailto:) or an in-page anchor: leave as-is *)
  else add_html_ext url

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
  (* The inner part of [@@ ... @@] may contain single [@] section separators
     ([@@a@b@c@@]) but must NOT span across a closing [@@]: each inner [@] has to
     be followed by a non-[@] char, so a [@@] always terminates the match.
     Otherwise a greedy match would swallow everything between two distant [@@]
     markers across the whole document. *)
  Str.global_substitute
    (Str.regexp "@@\\([^@]*\\(@[^@][^@]*\\)*\\)@@")
    (fun m ->
       let inner = Str.matched_group 1 m in
       let sections = String.split_on_char '@' inner |> List.map String.trim in
       Printf.sprintf "{%%wodoc:@ %s%%}" (String.concat " | " sections))
    s

(* wikicreole tables: each row is a line [|cell|cell|], a header cell starting
   with [|=]. odoc has no per-cell class/colspan (report "manque dur #2"), so we
   drop those cell attributes and the header-cell marker, and emit a plain odoc
   light table {t | c | c | }. Run after protect_links so any [[..|..]] link
   inside a cell is already a pipe-free placeholder; code is still protected, so
   OCaml [| pattern] lines are inside placeholders, not real rows. *)
let cell_attr_re = Str.regexp "@@\\([^@]*\\(@[^@][^@]*\\)*\\)@@"

let table_cell c =
  let c = String.trim c in
  let c =
    if String.length c > 0 && c.[0] = '='
    then String.sub c 1 (String.length c - 1)
    else c
  in
  String.trim (Str.global_replace cell_attr_re "" c)

let is_table_row line =
  let t = String.trim line in
  String.length t >= 2 && t.[0] = '|'

let emit_table rows =
  let buf = Buffer.create 256 in
  Buffer.add_string buf "{t\n";
  List.iter
    (fun row ->
      let row = String.trim row in
      let n = String.length row in
      let a = if n > 0 && row.[0] = '|' then 1 else 0 in
      let b = if n > a && row.[n - 1] = '|' then n - 1 else n in
      let cells =
        String.sub row a (b - a) |> String.split_on_char '|'
        |> List.map table_cell
      in
      Buffer.add_string buf (" | " ^ String.concat " | " cells ^ " |\n"))
    rows;
  Buffer.add_string buf "}";
  Buffer.contents buf

let tables_pass s =
  let lines = String.split_on_char '\n' s in
  let buf = Buffer.create (String.length s) in
  let rec go = function
    | [] -> ()
    | line :: rest when is_table_row line ->
        let rows, rest =
          let rec take acc = function
            | l :: r when is_table_row l -> take (l :: acc) r
            | r -> List.rev acc, r
          in
          take [ line ] rest
        in
        Buffer.add_string buf (emit_table rows);
        Buffer.add_char buf '\n';
        go rest
    | line :: rest ->
        Buffer.add_string buf line;
        Buffer.add_char buf '\n';
        go rest
  in
  go lines;
  (* drop the single trailing newline String.split/iter introduces *)
  let r = Buffer.contents buf in
  if String.length r > 0 && r.[String.length r - 1] = '\n'
  then String.sub r 0 (String.length r - 1)
  else r

let inline s =
  let s, links = protect_links s in
  let s = tables_pass s in
  let s = attrs_pass s in
  let s = toggle s "**" "{b " "}" in
  let s = toggle s "//" "{e " "}" in
  let s = toggle s "##" "[" "]" in
  let s = Str.global_replace (Str.regexp_string "\\\\") "{%html:<br/>%}" s in
  restore_links s links

let wiki_to_mld ?(default_side = "") ?(odoc_refs = false) s =
  let s = strip_comments s in
  let s, code = protect_code s in
  let s = wrappers ~default_side ~odoc_refs s in
  let s = lines_pass s in
  let s = inline s in
  let s = restore_code s code in
  s
