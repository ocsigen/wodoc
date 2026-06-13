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
  while !i < n && is_p s.[!i] do
    incr i
  done;
  while !j >= !i && is_p s.[!j] do
    decr j
  done;
  if !j < !i then "" else String.sub s !i (!j - !i + 1)

let is_lower c = c >= 'a' && c <= 'z'

(* Like [Str.global_substitute] but robust to the callback running its OWN [Str]
   matches: the next position is saved BEFORE calling [f], so [f] clobbering the
   global match state cannot derail the scan. [f] still reads the current match's
   groups, so it must read everything it needs before doing any other [Str] call
   (each callback below captures its groups on the first lines). *)
let global_sub re f s =
  let len = String.length s in
  let buf = Buffer.create len in
  let pos = ref 0 and continue = ref true in
  while !continue do
    match try Some (Str.search_forward re s !pos) with Not_found -> None with
    | None -> continue := false
    | Some start ->
        let e = Str.match_end () in
        Buffer.add_substring buf s !pos (start - !pos);
        Buffer.add_string buf (f s);
        if e > start
        then pos := e
        else (
          if start < len then Buffer.add_char buf s.[start];
          pos := start + 1);
        if !pos > len then continue := false
  done;
  if !pos <= len then Buffer.add_substring buf s !pos (len - !pos);
  Buffer.contents buf

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
      let last =
        match rest with [] -> "" | _ -> List.nth rest (List.length rest - 1)
      in
      let but_last l =
        match l with
        | [] -> []
        | _ -> List.filteri (fun i _ -> i < List.length l - 1) l
      in
      let dirs, anchor =
        if
          rest <> []
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
  global_sub span_re
    (fun whole ->
       (* capture groups before link_for runs its own Str matches *)
       let m0 = Str.matched_string whole in
       let title = try Str.matched_group 2 whole with Not_found -> "" in
       let visible = Str.matched_group 3 whole in
       let trailing = Str.matched_group 4 whole in
       let label = visible ^ trailing in
       match link_for siblings base (if title <> "" then title else label) with
       | Some url ->
           Printf.sprintf "<a href=\"%s\">%s</a>" url (html_escape label)
       | None -> m0)
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
    global_sub code_re
      (fun whole ->
         let m0 = Str.matched_string whole in
         let name = Str.matched_group 1 whole in
         match link_for siblings base name with
         | Some url ->
             Printf.sprintf "<a href=\"%s\"><code>%s</code></a>" url
               (html_escape name)
         | None -> m0)
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
      if j + sl > len
      then None
      else if String.sub s j sl = sub
      then Some j
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

(* ---- Cross-PROJECT references (resolve-deps.py) ----

   A page may reference another Ocsigen project. odoc(_driver --remap) renders a
   resolved dep as an absolute ocaml.org link; an unresolved one as an
   [xref-unresolved] span. For projects we host ourselves we rewrite both into
   RELATIVE links to that project's deployed docs. [hosted] maps a package to
   [(dir, multilib, wrapper)]: [dir] is its directory under the shared root,
   [multilib] whether its server/client libs sit in [<dir>.<side>/], [wrapper]
   its wrapping module (used to collapse a wrapped path to the flat layout the
   deployed docs use). *)

let flat_module wrapper comp =
  let pre = wrapper ^ "_" in
  if String.starts_with ~prefix:pre comp
  then comp
  else pre ^ String.lowercase_ascii comp

let flat_path wrapper path =
  let re =
    Str.regexp (Str.quote wrapper ^ "/\\([A-Z][A-Za-z0-9_']*\\)\\(/.*\\)?$")
  in
  if Str.string_match re path 0
  then
    let comp = Str.matched_group 1 path in
    let tail = try Str.matched_group 2 path with Not_found -> "" in
    flat_module wrapper comp ^ tail
  else path

let dep_base hosted relroot side pkg =
  let dir, multilib, _ = List.assoc pkg hosted in
  let b = relroot ^ "/" ^ dir ^ "/latest" in
  if multilib then b ^ "/" ^ dir ^ "." ^ side else b

let resolved_re =
  Str.regexp
    "href=\"https://ocaml\\.org/p/\\([^/\"]+\\)/[^/\"]+/doc/\\([^\"]+\\)\""

let fix_resolved hosted relroot side s =
  global_sub resolved_re
    (fun whole ->
       let m0 = Str.matched_string whole in
       let pkg = Str.matched_group 1 whole in
       let path = Str.matched_group 2 whole in
       match List.assoc_opt pkg hosted with
       | Some (_, _, wrapper) when not (String.starts_with ~prefix:"src/" path)
         ->
           Printf.sprintf "href=\"%s/%s\""
             (dep_base hosted relroot side pkg)
             (flat_path wrapper path)
       | _ -> m0)
    s

let fix_dep_spans hosted relroot side self s =
  let wrappers = List.map (fun (pkg, (_, _, w)) -> w, pkg) hosted in
  global_sub span_re
    (fun whole ->
       let m0 = Str.matched_string whole in
       let title = try Str.matched_group 2 whole with Not_found -> "" in
       let visible = Str.matched_group 3 whole in
       let trailing = Str.matched_group 4 whole in
       let label = visible ^ trailing in
       let raw = String.trim (if title <> "" then title else label) in
       let kind, after =
         if Str.string_match kind_re raw 0
         then Str.matched_group 1 raw, Str.match_end ()
         else "", 0
       in
       let name =
         strip_parens (String.sub raw after (String.length raw - after))
       in
       let toks =
         List.filter (fun t -> t <> "") (String.split_on_char '.' name)
       in
       match toks with
       | [] -> m0
       | head :: _ -> (
         match
           List.find_opt
             (fun (w, _) ->
                head = w || String.starts_with ~prefix:(w ^ "_") head)
             wrappers
         with
         | None -> m0 (* dep we do not host: leave as text *)
         | Some (wrapper, pkg) ->
             if pkg = self
             then m0 (* self ref: keep text *)
             else
               let modhead, rest =
                 if head = wrapper
                 then
                   match toks with
                   | _ :: m :: tl -> flat_module wrapper m, tl
                   | _ -> "", []
                 else head, List.tl toks
               in
               if modhead = ""
               then m0
               else begin
                 let last =
                   match rest with
                   | [] -> ""
                   | _ -> List.nth rest (List.length rest - 1)
                 in
                 let but_last l =
                   match l with
                   | [] -> []
                   | _ -> List.filteri (fun i _ -> i < List.length l - 1) l
                 in
                 let dirs, anchor =
                   if
                     rest <> []
                     && (kind = "val" || kind = "method"
                        || kind = ""
                           && String.length last > 0
                           && is_lower last.[0])
                   then but_last rest, "#val-" ^ last
                   else if rest <> [] && kind = "type"
                   then but_last rest, "#type-" ^ last
                   else rest, ""
                 in
                 let url =
                   dep_base hosted relroot side pkg
                   ^ "/" ^ modhead
                   ^ String.concat "" (List.map (fun d -> "/" ^ d) dirs)
                   ^ "/index.html" ^ anchor
                 in
                 Printf.sprintf "<a href=\"%s\">%s</a>" url (html_escape label)
               end))
    s

let deps ~hosted ~relroot ~side ~self s =
  fix_dep_spans hosted relroot side self (fix_resolved hosted relroot side s)

(* --- requalify cross-project links to wrapped libraries (post-pass) ---
   odoc_driver --remap names a reference to a wrapped library's module by a FLAT
   path (e.g. [Eliom_content]) while the wrapped project deploys it UNDER its
   wrapper: [Eliom/Content] for a renamed module, or [Eliom/Eliom_react] for one
   that kept its name. The mapping is therefore not uniform, so we PROBE: for a
   flat top segment [<W>_<x>] right after a wrapped project's [<dir>.<lib>/], try
   [<W>/<Cap x>] then [<W>/<W>_<x>] and keep the one whose target [exists]. *)
let cap s =
  if s = "" then s
  else String.make 1 (Char.uppercase_ascii s.[0]) ^ String.sub s 1 (String.length s - 1)

let requalify_url ~wrapped ~exists url =
  List.fold_left
    (fun url (dir, wrapper) ->
       (* the flat module sits right after either a multi-library segment
          ([<dir>.<lib>/], eliom/toolkit) or a version segment of a
          single-package manual-root project ([<dir>/<version>/], ocsigenserver). *)
       let res =
         [ Printf.sprintf "\\(/%s\\.[a-z_]+/\\)%s_\\([A-Za-z0-9_]+\\)"
             (Str.quote dir) (Str.quote wrapper)
         ; Printf.sprintf "\\(/%s/[^/]+/\\)%s_\\([A-Za-z0-9_]+\\)"
             (Str.quote dir) (Str.quote wrapper) ]
       in
       let try_re re =
         match Str.search_forward (Str.regexp re) url 0 with
         | exception Not_found -> None
         | _ ->
             let lib = Str.matched_group 1 url and rest = Str.matched_group 2 url in
             let b = Str.match_beginning () and e = Str.match_end () in
             let mk seg =
               String.sub url 0 b ^ lib ^ wrapper ^ "/" ^ seg
               ^ String.sub url e (String.length url - e)
             in
             let c1 = mk (cap rest) and c2 = mk (wrapper ^ "_" ^ rest) in
             if exists c1 then Some c1 else if exists c2 then Some c2 else None
       in
       match List.find_map try_re res with Some u -> u | None -> url)
    url wrapped

(* A cross-project link that omits the version segment ([../../eliom/page.html]
   instead of [../../eliom/latest/page.html]): insert [latest/] after the project
   segment (the first one past any [../] / leading [/]). [None] if there is no
   such segment or it is already a version. *)
let latest_insert url =
  let re = Str.regexp "^\\(\\(\\.\\./\\)*\\|/\\)\\([A-Za-z][A-Za-z0-9_-]*\\)/\\(.+\\)$" in
  if Str.string_match re url 0 then (
    let pre = Str.matched_group 1 url
    and proj = Str.matched_group 3 url
    and rest = Str.matched_group 4 url in
    if String.length rest >= 7 && String.sub rest 0 7 = "latest/"
    then None
    else Some (pre ^ proj ^ "/latest/" ^ rest))
  else None

(* [requalify ~wrapped ~exists page] repairs BROKEN cross-project links in every
   href/src of [page] by probing: a link that already resolves is left as is;
   otherwise try the wrapped flat→qualified rewrite, then a missing-[latest/]
   version-segment insertion, keeping the first candidate that [exists]. *)
let requalify ~wrapped ~exists page =
  let re = Str.regexp "\\(href\\|src\\)=\"\\([^\"]*\\)\"" in
  global_sub re
    (fun s ->
       let attr = Str.matched_group 1 s and url = Str.matched_group 2 s in
       let fixed =
         if url = "" || exists url
         then url
         else
           let w = requalify_url ~wrapped ~exists url in
           if w <> url && exists w
           then w
           else match latest_insert url with Some v when exists v -> v | _ -> url
       in
       Printf.sprintf "%s=\"%s\"" attr fixed)
    page
