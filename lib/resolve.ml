(* Link cross-PACKAGE "sibling" references that odoc left unresolved into
   RELATIVE links within one version's output.

   `dune build @doc` documents every sibling package into the same tree, but
   odoc only resolves references along dependency edges; a base library does not
   depend on its sibling packages, so a reference like [{!Lwt_react.S}] is left
   unresolved — rendered either as

     <span class="xref-unresolved" title="Lwt_react.S">S</span>

   or, for a bare [{!Ppx_lwt}], as a plain inline <code>Ppx_lwt</code> — even
   though that module IS built, in a sibling directory of the same version. We
   rewrite those into relative links to the sibling's subtree. References that
   are not rooted at a known sibling (Stdlib, internal/hidden modules, real
   deps) are left as text — exactly as odoc/ocamldoc leave them.

   This is the OCaml port of the per-project resolve-siblings.py scripts; the
   sibling table (top module -> path segments of that module's own directory,
   under the version root) is passed in as data, so one implementation serves
   every project. *)

let html_escape s =
  let b = Buffer.create (String.length s) in
  String.iter
    (fun c ->
       match c with
       | '&' -> Buffer.add_string b "&amp;"
       | '<' -> Buffer.add_string b "&lt;"
       | '>' -> Buffer.add_string b "&gt;"
       | '"' -> Buffer.add_string b "&quot;"
       | '\'' -> Buffer.add_string b "&#x27;"
       | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let kind_re =
  Str.regexp "^\\(val\\|type\\|module\\|exception\\|method\\|class\\)[ \t\n]+"

(* strip the characters '(' ')' ' ' from both ends, like Python's strip("() ") *)
let strip_parens s =
  let is_p c = c = '(' || c = ')' || c = ' ' in
  let n = String.length s in
  let i = ref 0 and j = ref (n - 1) in
  while !i < n && is_p s.[!i] do incr i done;
  while !j >= !i && is_p s.[!j] do decr j done;
  if !j < !i then "" else String.sub s !i (!j - !i + 1)

let is_lower c = c >= 'a' && c <= 'z'

(* [link_for siblings base raw] is the relative URL for a qualified name rooted
   at a known sibling, or [None]. [raw] may carry a "val "/"type "/… kind
   prefix (from a value/type/… spec heading). *)
let link_for siblings base raw =
  let raw = String.trim raw in
  let kind, after =
    if Str.string_match kind_re raw 0
    then Str.matched_group 1 raw, Str.match_end ()
    else "", 0
  in
  let name = strip_parens (String.sub raw after (String.length raw - after)) in
  let toks = List.filter (fun t -> t <> "") (String.split_on_char '.' name) in
  match toks with
  | top :: rest when List.mem_assoc top siblings ->
      let base_segs = List.assoc top siblings in
      let last = match rest with [] -> "" | _ -> List.nth rest (List.length rest - 1) in
      let but_last l = match l with [] -> [] | _ -> List.filteri (fun i _ -> i < List.length l - 1) l in
      let dirs, anchor =
        if rest <> []
           && (kind = "val" || kind = "method"
              || (kind = "" && String.length last > 0 && is_lower last.[0]))
        then but_last rest, "#val-" ^ last
        else if rest <> [] && kind = "type"
        then but_last rest, "#type-" ^ last
        else rest, ""
      in
      let segs = base_segs @ dirs in
      Some (base ^ "/" ^ String.concat "/" segs ^ "/index.html" ^ anchor)
  | _ -> None

(* <span class="xref-unresolved" [title="…"]>visible</span>.trailing.members *)
let span_re =
  Str.regexp
    "<span class=\"xref-unresolved[^\"]*\"\\( title=\"\\([^\"]*\\)\"\\)?>\\([^<]*\\)</span>\\(\\(\\.[A-Za-z_][A-Za-z0-9_']*\\)*\\)"

let fix_spans siblings base s =
  Str.global_substitute span_re
    (fun whole ->
       let title = try Str.matched_group 2 whole with Not_found -> "" in
       let visible = Str.matched_group 3 whole in
       let trailing = Str.matched_group 4 whole in
       let label = visible ^ trailing in
       match link_for siblings base (if title <> "" then title else label) with
       | Some url -> Printf.sprintf "<a href=\"%s\">%s</a>" url (html_escape label)
       | None -> Str.matched_string whole)
    s

(* a bare unresolved ref renders as <code>Sib.path</code>; link only those
   rooted at a known sibling (so ordinary code spans are left alone). *)
let fix_codes siblings base s =
  let alt =
    String.concat "\\|" (List.map (fun (k, _) -> Str.quote k) siblings)
  in
  if alt = ""
  then s
  else
    let code_re =
      Str.regexp
        (Printf.sprintf
           "<code>\\(\\(%s\\)\\(\\.[A-Za-z_][A-Za-z0-9_']*\\)*\\)</code>" alt)
    in
    Str.global_substitute code_re
      (fun whole ->
         let name = Str.matched_group 1 whole in
         match link_for siblings base name with
         | Some url ->
             Printf.sprintf "<a href=\"%s\"><code>%s</code></a>" url
               (html_escape name)
         | None -> Str.matched_string whole)
      s

let process siblings base segment =
  fix_codes siblings base (fix_spans siblings base segment)

(* run [f] on every region OUTSIDE a <pre>…</pre> block (qualified names inside
   are example source, not references), splicing the <pre> blocks back verbatim *)
let outside_pre f s =
  let len = String.length s in
  let b = Buffer.create len in
  let i = ref 0 in
  let find sub from =
    let sl = String.length sub in
    let rec go j =
      if j + sl > len then None
      else if String.sub s j sl = sub then Some j
      else go (j + 1)
    in
    go from
  in
  let continue = ref true in
  while !continue do
    match find "<pre" !i with
    | None ->
        Buffer.add_string b (f (String.sub s !i (len - !i)));
        continue := false
    | Some p -> (
        Buffer.add_string b (f (String.sub s !i (p - !i)));
        match find "</pre>" p with
        | None ->
            (* no close: emit the rest verbatim, like a code block *)
            Buffer.add_substring b s p (len - p);
            continue := false
        | Some e ->
            let stop = e + String.length "</pre>" in
            Buffer.add_substring b s p (stop - p);
            i := stop)
  done;
  Buffer.contents b

let html ~siblings ~base s = outside_pre (process siblings base) s
