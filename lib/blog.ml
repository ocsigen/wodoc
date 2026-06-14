(* An ultra-simple blog for wodoc sites. A post is a plain [.mld] named
   [YYYY-MM-DD-slug.mld]: the date prefix is the publication date (so posts sort
   newest-first with no metadata file), the author comes from odoc's native
   [@author] tag, the title from the page heading and the excerpt from the first
   paragraph. Posts build like any other page; this module only derives the
   metadata, the generated left-nav section and the "latest posts" landing
   fragment. Generic — no project-specific assumptions. Driven by {!Config.blog}. *)

type post =
  { date : string
  ; slug : string
  ; src : string
  ; path : string
  ; title : string
  ; author : string
  ; excerpt : string }

let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let is_ws c = c = ' ' || c = '\t' || c = '\n' || c = '\r'

(* Strip odoc inline markup to plain text, best-effort (titles and excerpts are
   short prose, not arbitrary markup). Drops a markup opener and its braces,
   keeping the inner text: [{e x}]/[{b x}]/[{i x}] -> "x"; a link [{{:url}text}]
   or cross-ref [{{!ref}text}] -> "text" (the target is skipped); [{!ref}] -> ""
   (a bare ref has no display text); [[code]] -> "code". Whitespace is collapsed. *)
let plain s =
  let n = String.length s in
  let b = Buffer.create n in
  let i = ref 0 in
  while !i < n do
    match s.[!i] with
    | '{' ->
        incr i;
        if !i < n && s.[!i] = '{'
        then begin
          (* [{{:url}text}] / [{{!ref}text}] : skip up to the target's '}' *)
          incr i;
          while !i < n && s.[!i] <> '}' do
            incr i
          done;
          if !i < n then incr i (* the '}' closing the target *)
        end
        else
          (* [{tag ...}] : skip the tag word (and one following space) *)
          while !i < n && (not (is_ws s.[!i])) && s.[!i] <> '}' do
            incr i
          done
    | '}' | '[' | ']' -> incr i
    | c -> Buffer.add_char b c; incr i
  done;
  (* collapse runs of whitespace into single spaces, trim *)
  let raw = Buffer.contents b in
  let out = Buffer.create (String.length raw) in
  let prev_ws = ref true in
  String.iter
    (fun c ->
       if is_ws c
       then (
         if not !prev_ws then Buffer.add_char out ' ';
         prev_ws := true)
       else (
         Buffer.add_char out c;
         prev_ws := false))
    raw;
  String.trim (Buffer.contents out)

(* the index of the post's first heading opener ([{0 …}] or [{1 …}]), if any *)
let find_heading s =
  let n = String.length s in
  let rec go i =
    if i + 2 >= n
    then None
    else if
      s.[i] = '{' && (s.[i + 1] = '0' || s.[i + 1] = '1') && is_ws s.[i + 2]
    then Some i
    else go (i + 1)
  in
  go 0

(* the content of the brace group opened at [open_idx] (text after the heading
   level and its space, up to the matching '}'), plus the index just past it. *)
let braced s open_idx =
  let n = String.length s in
  let depth = ref 0 and started = ref false and stop = ref n in
  let buf = Buffer.create 64 in
  let i = ref open_idx in
  (try
     while !i < n do
       let c = s.[!i] in
       if c = '{'
       then incr depth
       else if c = '}'
       then (
         decr depth;
         if !depth = 0
         then (
           stop := !i + 1;
           raise Exit));
       if !started
       then Buffer.add_char buf c
       else if is_ws c
       then started := true;
       incr i
     done
   with Exit -> ());
  Buffer.contents buf, !stop

(* title (plain text) and the index just past the heading; ("", 0) if none *)
let title_and_body s =
  match find_heading s with
  | None -> "", 0
  | Some idx ->
      let content, stop = braced s idx in
      plain content, stop

(* the [@author …] of a post (rest of the line), plain text; "" when absent *)
let author s =
  match Str.search_forward (Str.regexp "@author[ \t]+") s 0 with
  | exception Not_found -> ""
  | _ ->
      let e = Str.match_end () in
      let stop =
        match String.index_from_opt s e '\n' with
        | Some j -> j
        | None -> String.length s
      in
      plain (String.sub s e (stop - e))

let excerpt_len = 240

(* the first paragraph after the heading, as plain text, truncated: skip leading
   blank lines and any odoc block tags ([@author], [@since]…, which are not prose),
   then read up to the next blank line, the next heading or the end. *)
let excerpt s start =
  let n = String.length s in
  let i = ref start in
  let again = ref true in
  while !again do
    while !i < n && is_ws s.[!i] do
      incr i
    done;
    if !i < n && s.[!i] = '@'
    then
      (* a tag line ([@author …]): skip to the end of its line and look again *)
      i := match String.index_from_opt s !i '\n' with Some j -> j | None -> n
    else again := false
  done;
  let para_end =
    match Str.search_forward (Str.regexp "\n[ \t]*\n") s !i with
    | j -> j
    | exception Not_found -> n
  in
  let head_end =
    match find_heading (String.sub s !i (n - !i)) with
    | Some k -> !i + k
    | None -> n
  in
  let stop = min para_end head_end in
  let text = plain (String.sub s !i (stop - !i)) in
  if String.length text <= excerpt_len
  then text
  else String.sub text 0 excerpt_len ^ "…"

(* file name [YYYY-MM-DD-slug.mld] -> (date, slug) *)
let dated_re =
  Str.regexp "^\\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\)-\\(.+\\)\\.mld$"

let posts (b : Config.blog) =
  if not (Sys.file_exists b.dir)
  then []
  else
    Sys.readdir b.dir |> Array.to_list
    |> List.filter_map (fun e ->
      if not (Str.string_match dated_re e 0)
      then None
      else
        let date = Str.matched_group 1 e in
        let slug = Str.matched_group 2 e in
        let src = Filename.concat b.dir e in
        let s = read_file src in
        let title, after = title_and_body s in
        Some
          { date
          ; slug
          ; src
          ; path =
              (if b.out = ""
               then slug ^ ".html"
               else b.out ^ "/" ^ slug ^ ".html")
          ; title = (if title = "" then slug else title)
          ; author = author s
          ; excerpt = excerpt s after })
    (* newest first; ties broken by slug for a stable order *)
    |> List.sort (fun p q ->
      let c = compare q.date p.date in
      if c <> 0 then c else compare p.slug q.slug)

let nav_section (b : Config.blog) (posts : post list) : Config.section =
  { heading = b.heading
  ; api = false
  ; items =
      List.map
        (fun p ->
           Config.Link
             {label = p.date ^ " — " ^ p.title; path = p.path; current = p.path})
        posts }

let esc = Resolve.html_escape

let latest_fragment ~base (b : Config.blog) (posts : post list) =
  let recent = List.filteri (fun i _ -> i < b.latest) posts in
  if recent = []
  then ""
  else begin
    let buf = Buffer.create 512 in
    let add = Buffer.add_string buf in
    add "<ul class=\"wodoc-blog-list\">\n";
    List.iter
      (fun p ->
         let href = (if base = "" then "" else base ^ "/") ^ p.path in
         add "<li class=\"wodoc-blog-card\">\n";
         add
           (Printf.sprintf
              "  <a class=\"wodoc-blog-title\" href=\"%s\">%s</a>\n" (esc href)
              (esc p.title));
         add "  <p class=\"wodoc-blog-meta\">";
         add (esc p.date);
         if p.author <> ""
         then (
           add " — ";
           add (esc p.author));
         add "</p>\n";
         if p.excerpt <> ""
         then
           add
             (Printf.sprintf "  <p class=\"wodoc-blog-excerpt\">%s</p>\n"
                (esc p.excerpt));
         add "</li>\n")
      recent;
    add "</ul>\n";
    Buffer.contents buf
  end

(* The landing sentinel: an HTML comment whose target uses a hyphen, NOT the
   [<!--wodoc:…-->] colon form, so {!Render} (which scans for [<!--wodoc:]) leaves
   it untouched, stock odoc keeps it (invisible on ocaml.org), and {!val:expand}
   substitutes it. Reached from either [{%html:<!--wodoc-blog-latest-->%}] (any
   build path) or [{%wodoc:blog-latest%}] (preprocessed paths; see {!Render}). *)
let marker = "<!--wodoc-blog-latest-->"

let expand ~fragment html =
  (* drop odoc's surrounding <p> when the marker is its own paragraph, so a block
     <ul> is not nested in a <p>; then substitute any remaining bare marker. The
     generated fragment never contains '\\', so it is a safe Str replacement. *)
  let wrapped = Str.regexp ("<p>[ \t\r\n]*" ^ marker ^ "[ \t\r\n]*</p>") in
  let html = Str.global_replace wrapped fragment html in
  Str.global_replace (Str.regexp_string marker) fragment html
