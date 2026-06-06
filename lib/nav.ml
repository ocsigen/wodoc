(* Build a manual's left-column navigation from its wikicréole menu
   (menu.wiki): [==]/[===] headings become section labels, and the various link
   forms become entries. The OCaml port of the per-project gen-manual-nav.py
   scripts; the differences between projects (where manual pages live, which
   link forms appear, the API landing map) are options, so one implementation
   serves every project.

   Recognised per menu line [=+]<text>:
   - [[page|Title]]            -> a manual page: <base>[/<pkg>]/<page>.html
   - <<mod PATH|Title>>        -> an API module dir: <base>/<PATH>/index.html
   - <<a_api subproject="P" [text="T"]|body>>
                               -> the API landing of package P (see [api_href])
   - <<a_file src="S"|T>>      -> a download: <base>/<pkg>/files/S
   - plain text (no << or [[)  -> a section heading <h4 class="mlN">
   Anything else (e.g. external <<a_manual project="tuto">>) is skipped. *)

let head_re = Str.regexp "^\\(=+\\)[ \t]*\\(.*\\)$"
let link_re = Str.regexp "^\\[\\[\\([^|]+\\)|\\([^]]+\\)\\]\\]"
let mod_re = Str.regexp "^<<mod[ \t]+\\([^|>]+\\)|\\([^>]+\\)>>"
let a_api_re = Str.regexp "<<a_api\\([^|>]*\\)|\\([^>]*\\)>>"
let a_file_re = Str.regexp "<<a_file[^>]*src=\"\\([^\"]+\\)\"[^|>]*|\\([^>]*\\)>>"
let attr_re name = Str.regexp (name ^ "=\"\\([^\"]+\\)\"")

let attr name s =
  try ignore (Str.search_forward (attr_re name) s 0); Some (Str.matched_group 1 s)
  with Not_found -> None

let contains s sub =
  let sl = String.length sub and n = String.length s in
  let rec go i = i + sl <= n && (String.sub s i sl = sub || go (i + 1)) in
  sl = 0 || go 0

(* Build the manual nav HTML for [menu] (the wiki source as a string).
   [pkg]: package dir carrying the manual pages ("" -> pages at <base>/<page>.html).
   [heading]: the <h3> label (e.g. "Manual", "Lwt").
   [api_map]: subproject -> path (relative to base) for <<a_api>> landings;
   an unknown subproject falls back to <subproject>/index.html. *)
let manual ?(pkg = "") ?(heading = "Manual") ?(api_map = []) ~base menu =
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  add "<nav class=\"api-nav manual-nav\">";
  add (Printf.sprintf "<h3>%s</h3>" (Resolve.html_escape heading));
  let open_ul = ref false in
  let close () = if !open_ul then (add "</ul>"; open_ul := false) in
  let open_section () = if not !open_ul then (add "<ul class=\"api-section\">"; open_ul := true) in
  let esc = Resolve.html_escape in
  let page_url page = if pkg = "" then base ^ "/" ^ page ^ ".html" else base ^ "/" ^ pkg ^ "/" ^ page ^ ".html" in
  let api_href sub =
    match List.assoc_opt sub api_map with
    | Some p -> base ^ "/" ^ p
    | None -> base ^ "/" ^ sub ^ "/index.html"
  in
  List.iter
    (fun raw ->
       let line = raw in
       if Str.string_match head_re line 0
       then begin
         let level = String.length (Str.matched_group 1 line) in
         let text = String.trim (Str.matched_group 2 line) in
         if Str.string_match link_re text 0
         then begin
           let page = String.trim (Str.matched_group 1 text) in
           let title = String.trim (Str.matched_group 2 text) in
           open_section ();
           add (Printf.sprintf
                  "<li class=\"ml%d\" data-wodoc-page=\"%s\"><a href=\"%s\">%s</a></li>"
                  level page (page_url page) (esc title))
         end
         else if Str.string_match mod_re text 0
         then begin
           let path =
             let p = String.trim (Str.matched_group 1 text) in
             (* strip surrounding '/' like Python .strip("/") *)
             let n = String.length p in
             let i = ref 0 and j = ref (n - 1) in
             while !i < n && p.[!i] = '/' do incr i done;
             while !j >= !i && p.[!j] = '/' do decr j done;
             if !j < !i then "" else String.sub p !i (!j - !i + 1)
           in
           let title = String.trim (Str.matched_group 2 text) in
           open_section ();
           add (Printf.sprintf "<li class=\"ml%d\"><a href=\"%s/%s/index.html\">%s</a></li>"
                  level base path (esc title))
         end
         else if (try ignore (Str.search_forward a_api_re text 0); true with Not_found -> false)
         then begin
           let attrs = Str.matched_group 1 text in
           let body = String.trim (Str.matched_group 2 text) in
           let sub = match attr "subproject" attrs with Some s -> s | None -> (if pkg = "" then "" else pkg) in
           let title = match attr "text" attrs with Some t -> t | None -> body in
           open_section ();
           add (Printf.sprintf "<li class=\"ml%d\"><a href=\"%s\">%s</a></li>"
                  level (api_href sub) (esc title))
         end
         else if (try ignore (Str.search_forward a_file_re text 0); true with Not_found -> false)
         then begin
           let src = Str.matched_group 1 text in
           let title = String.trim (Str.matched_group 2 text) in
           open_section ();
           add (Printf.sprintf "<li class=\"ml%d\"><a href=\"%s/%s/files/%s\">%s</a></li>"
                  level base pkg src (esc title))
         end
         else if text <> "" && not (contains text "<<") && not (contains text "[[")
         then begin
           close ();
           add (Printf.sprintf "<h4 class=\"ml%d\">%s</h4>" level (esc text))
         end
       end)
    (String.split_on_char '\n' menu);
  close ();
  add "</nav>";
  Buffer.contents buf

(* ---- API module navigation, from a curated .indexdoc (gen-nav.py) ---- *)

(* Tokenise an .indexdoc into (section-title option, modules) pairs, matching
   the Python finditer over [{N <title>}] and [{!modules: …}] (the latter
   non-greedy, i.e. up to the FIRST closing brace — replicated exactly so the
   output matches, including the truncation when a [{!indexlist}] appears). *)
let index_sections text =
  let len = String.length text in
  let sections = ref [] and pending = ref None in
  let i = ref 0 in
  let is_ws c = c = ' ' || c = '\t' || c = '\n' || c = '\r' in
  while !i < len do
    if text.[!i] = '{'
       && !i + 1 < len
       && text.[!i + 1] >= '1'
       && text.[!i + 1] <= '9'
       && !i + 2 < len
       && is_ws text.[!i + 2]
    then (
      (* {N <title>} heading: title is everything up to the next '}' *)
      match String.index_from_opt text !i '}' with
      | None -> i := len
      | Some e ->
          let s = !i + 2 in
          pending := Some (String.trim (String.sub text s (e - s)));
          i := e + 1)
    else if !i + 10 <= len && String.sub text !i 10 = "{!modules:"
    then (
      match String.index_from_opt text (!i + 10) '}' with
      | None -> i := len
      | Some e ->
          let content = String.sub text (!i + 10) (e - (!i + 10)) in
          let mods =
            List.filter (fun s -> s <> "")
              (String.split_on_char ' '
                 (String.map (fun c -> if is_ws c then ' ' else c) content))
          in
          sections := (!pending, mods) :: !sections;
          pending := None;
          i := e + 1)
    else incr i
  done;
  List.rev !sections

let api ?(wrapper = "") ?(heading = "Modules") ?(skip = []) ~base ~lib indexdoc =
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  let esc = Resolve.html_escape in
  add "<nav class=\"api-nav\">";
  add (Printf.sprintf "<h3>%s</h3>" (esc heading));
  let prefix = if wrapper = "" then "" else wrapper ^ "/" in
  let page_url m =
    base ^ "/" ^ lib ^ "/" ^ prefix
    ^ String.concat "/" (String.split_on_char '.' m)
    ^ "/index.html"
  in
  List.iter
    (fun (title, mods) ->
       (* drop odoc directives like {!indexlist} that may sit in a module list *)
       let mods =
         List.filter
           (fun m -> not (String.length m >= 2 && m.[0] = '{' && m.[1] = '!'))
           mods
       in
       if mods <> []
       then begin
         (match title with
          | Some t when t <> "" && not (List.mem t skip) ->
              add (Printf.sprintf "<h4>%s</h4>" (esc t))
          | _ -> ());
         add "<ul class=\"api-section\">";
         List.iter
           (fun m ->
              add (Printf.sprintf
                     "<li data-wodoc-page=\"%s\"><a href=\"%s\">%s</a></li>"
                     (esc m) (page_url m) (esc m)))
           mods;
         add "</ul>"
       end)
    (index_sections indexdoc);
  add "</nav>";
  Buffer.contents buf

(* ---- Single-page anchor navigation (gen-anchor-nav.py) ---- *)

let braces_re = Str.regexp "{{{\\([^}]*\\)}}}"
let mono_re = Str.regexp "##\\([^#]*\\)##"
let anchor_link_re = Str.regexp "^\\[\\[#\\([^|]+\\)|\\([^]]+\\)\\]\\]"

let clean t =
  let t = Str.global_replace braces_re "\\1" t in
  let t = Str.global_replace mono_re "\\1" t in
  String.trim t

let anchors ?(heading = "Manual") ~base menu =
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  let esc = Resolve.html_escape in
  add "<nav class=\"api-nav manual-nav\">";
  add (Printf.sprintf "<h3>%s</h3>" (esc heading));
  let open_ul = ref false in
  let close () = if !open_ul then (add "</ul>"; open_ul := false) in
  List.iter
    (fun line ->
       if Str.string_match head_re line 0
       then begin
         let level = String.length (Str.matched_group 1 line) in
         let text = String.trim (Str.matched_group 2 line) in
         if Str.string_match anchor_link_re text 0
         then begin
           let anchor = String.trim (Str.matched_group 1 text) in
           let title = clean (Str.matched_group 2 text) in
           if not !open_ul then (add "<ul class=\"api-section\">"; open_ul := true);
           add (Printf.sprintf
                  "<li class=\"ml%d\"><a href=\"%s/index.html#%s\">%s</a></li>"
                  level base anchor (esc title))
         end
         else begin
           let title = clean text in
           if title <> "" && not (contains text "[[") && not (contains text "<<")
           then (close (); add (Printf.sprintf "<h4 class=\"ml%d\">%s</h4>" level (esc title)))
         end
       end)
    (String.split_on_char '\n' menu);
  close ();
  add "</nav>";
  Buffer.contents buf
