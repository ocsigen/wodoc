(* API module navigation, from a curated .indexdoc (the OCaml port of the
   per-project gen-nav.py script). The .indexdoc is a curated *odoc* index
   ([{N <title>}] section headings + [{!modules: …}] lists), NOT wikicréole:
   the manual's own left navigation is described declaratively in the project's
   [doc/wodoc] config (the [(nav …)] stanza, see {!Config} and {!Build}). *)

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
    if
      text.[!i] = '{'
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
            List.filter
              (fun s -> s <> "")
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
              add
                (Printf.sprintf
                   "<li data-wodoc-page=\"%s\"><a href=\"%s\">%s</a></li>"
                   (esc m) (page_url m) (esc m)))
           mods;
         add "</ul>"
       end)
    (index_sections indexdoc);
  add "</nav>";
  Buffer.contents buf
