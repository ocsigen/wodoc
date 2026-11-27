(* An ultra-simple blog for wodoc sites. A post is a plain [.mld] named
   [YYYY-MM-DD-slug.mld]: the date prefix is the publication date (so posts sort
   newest-first with no metadata file), the author comes from odoc's native
   [@author] tag, the title from the page heading and the excerpt from the first
   paragraph. Posts build like any other page; this module only derives the
   metadata, the generated left-nav section and the "latest posts" landing
   fragment. Generic — no project-specific assumptions. Driven by {!Config.blog}. *)

open Util

type post =
  { date : string
  ; slug : string
  ; src : string
  ; path : string
  ; title : string
  ; author : string
  ; excerpt : string }

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

(* the [@author …] tags of a post (rest of each line), plain text, joined with
   ", "; "" when absent *)
let author s =
  let re = Str.regexp "@author[ \t]+" in
  let rec tags from acc =
    match Str.search_forward re s from with
    | exception Not_found -> List.rev acc
    | _ ->
        let e = Str.match_end () in
        let stop =
          match String.index_from_opt s e '\n' with
          | Some j -> j
          | None -> String.length s
        in
        tags stop (plain (String.sub s e (stop - e)) :: acc)
  in
  String.concat ", " (tags 0 [])

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
  else
    (* cut before the character holding byte [excerpt_len], not inside it:
       a UTF-8 continuation byte is 0b10xxxxxx *)
    let rec start i =
      if i > 0 && Char.code text.[i] land 0xC0 = 0x80 then start (i - 1) else i
    in
    String.sub text 0 (start excerpt_len) ^ "…"

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

let nav_section (b : Config.blog) (posts : post list) : _ Config.section =
  { heading = b.heading
  ; api = false
  ; items =
      List.map
        (fun p ->
           Config.Link
             {label = p.date ^ " — " ^ p.title; path = p.path; current = p.path})
        posts }

let esc = Resolve.html_escape

(* the blog's left-nav block, rendered exactly like {!Build.manual_nav} renders a
   manual [(section …)] (a [<nav class="api-nav manual-nav">] with an [<h3>] and
   one [ml3] [<li>] per entry), so the shared CSS styles it identically. Used by
   the [wodoc blog-nav] command to feed the low-level [assemble --leftnav] path
   (the turn-key [wodoc build] path splices {!nav_section} instead). [base] is the
   per-page relative path to the blog root. *)
let nav_html ~base (b : Config.blog) (posts : post list) =
  let buf = Buffer.create 512 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  add "<nav class=\"api-nav manual-nav\">";
  add (Printf.sprintf "<h3>%s</h3>" (esc b.heading));
  add "<ul class=\"api-section\">";
  List.iter
    (fun p ->
       let href = (if base = "" then "" else base ^ "/") ^ p.path in
       add
         (Printf.sprintf
            "<li class=\"ml3\" data-wodoc-page=\"%s\"><a href=\"%s\">%s</a></li>"
            (esc p.path) (esc href)
            (esc (p.date ^ " — " ^ p.title))))
    posts;
  add "</ul>";
  add "</nav>";
  Buffer.contents buf

(* an Atom feed of the posts (newest first), for syndication (e.g. OCaml Planet).
   [base_url] is the site origin (e.g. "https://ocsigen.org"); a post's URL is
   [base_url ^ blog_path ^ "/" ^ post.path] (blog_path = the blog root from the
   origin, e.g. "/blog"); the feed advertises itself at [base_url ^ feed_path].
   Entry bodies are the post excerpt as an HTML [<summary>]. [updated] is taken
   from the newest post's date (so the feed is stable across rebuilds). *)
let feed ~base_url ~blog_path ~feed_path ~title ~author (posts : post list) =
  let rfc3339 date = date ^ "T00:00:00+00:00" in
  let post_url p = base_url ^ blog_path ^ "/" ^ p.path in
  let updated =
    match posts with
    | p :: _ -> rfc3339 p.date
    | [] -> "1970-01-01T00:00:00+00:00"
  in
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  add {|<?xml version="1.0" encoding="utf-8"?>|};
  add {|<feed xmlns="http://www.w3.org/2005/Atom">|};
  add (Printf.sprintf "  <title>%s</title>" (esc title));
  add
    (Printf.sprintf "  <link href=\"%s%s\" rel=\"self\" />" (esc base_url)
       (esc feed_path));
  add (Printf.sprintf "  <link href=\"%s\" />" (esc base_url));
  add (Printf.sprintf "  <updated>%s</updated>" updated);
  add (Printf.sprintf "  <id>%s/</id>" (esc base_url));
  add (Printf.sprintf "  <author><name>%s</name></author>" (esc author));
  List.iter
    (fun p ->
       let url = post_url p in
       add "  <entry>";
       add (Printf.sprintf "    <title>%s</title>" (esc p.title));
       add (Printf.sprintf "    <link href=\"%s\" />" (esc url));
       add (Printf.sprintf "    <updated>%s</updated>" (rfc3339 p.date));
       add (Printf.sprintf "    <id>%s</id>" (esc url));
       if p.author <> ""
       then
         add
           (Printf.sprintf "    <author><name>%s</name></author>" (esc p.author));
       if p.excerpt <> ""
       then
         add
           (Printf.sprintf "    <summary type=\"html\">%s</summary>"
              (esc p.excerpt));
       add "  </entry>")
    posts;
  add "</feed>";
  Buffer.contents buf

let md_path p = Filename.remove_extension p.path ^ ".md"

let published p =
  if p.author = ""
  then Printf.sprintf "Published on %s." p.date
  else Printf.sprintf "Published on %s by %s." p.date p.author

(* an ATX heading line, of any level: one or more '#' then a space *)
let is_heading l =
  let n = String.length l in
  let rec hashes i = if i < n && l.[i] = '#' then hashes (i + 1) else i in
  let k = hashes 0 in
  k > 0 && k < n && l.[k] = ' '

(* odoc renders the post's title ([{0 …}] or [{1 …}]) as the first line of the
   page, and each [@author] tag as an "author <name>" line right after it, glued
   to the first paragraph. The publication line takes the place of those tag
   lines (the HTML page hides the tags too, and shows the byline instead), and
   goes first in a page that does not start with a title. *)
let markdown_twin p md =
  let rec drop_authors = function
    | "" :: rest -> drop_authors rest
    | l :: rest when p.author <> "" && String.starts_with ~prefix:"author " l ->
        drop_authors rest
    | rest -> rest
  in
  let rec place = function
    | "" :: rest -> place rest
    | l :: rest when is_heading l ->
        l :: "" :: published p :: "" :: drop_authors rest
    | lines -> published p :: "" :: drop_authors lines
  in
  String.concat "\n" (place (String.split_on_char '\n' (Render.markdown md)))

(* Every rendering is read before anything is written, so that a missing or
   unreadable one leaves the previous twins and indexes in place rather than
   half a set. *)
let write_llms ~md_dir ~out ~title ~summary (posts : post list) =
  let read p =
    let f = Filename.concat md_dir (p.slug ^ ".md") in
    match read_file f with
    | s -> Either.Left (p, s)
    | exception Sys_error m -> Either.Right m
  in
  match List.partition_map read posts with
  | _, (_ :: _ as errors) ->
      Error
        ("cannot read the Markdown rendering of a post: "
       ^ String.concat "; " errors)
  | renderings, [] -> (
    try
      mkdir_p out;
      let twins = List.map (fun (p, md) -> p, markdown_twin p md) renderings in
      List.iter
        (fun (p, twin) ->
           let dst = Filename.concat out (md_path p) in
           mkdir_p (Filename.dirname dst);
           write_file dst twin)
        twins;
      let header = Printf.sprintf "# %s\n\n> %s\n" title summary in
      let entry p =
        let notes =
          if p.excerpt = "" then published p else published p ^ " " ^ p.excerpt
        in
        Printf.sprintf "- [%s](%s): %s\n" p.title (md_path p) notes
      in
      let index =
        if posts = []
        then header
        else header ^ "\n## Posts\n" ^ String.concat "" (List.map entry posts)
      in
      write_file (Filename.concat out "llms.txt") index;
      let full =
        header
        ^ String.concat ""
            (List.map
               (fun (_, twin) -> "\n\n---\n\n" ^ String.trim twin ^ "\n")
               twins)
      in
      write_file (Filename.concat out "llms-full.txt") full;
      Ok ()
    with Sys_error m -> Error ("cannot write the Markdown twins: " ^ m))

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
