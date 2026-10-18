(* The manual's page tree, read from the sidebar.json odoc_driver writes next to
   each package's pages. See page_tree.mli. *)

type node =
  { label : string  (** plain text of the entry *)
  ; url : string option
    (** the page, relative to [src]; [None] for an entry that is not a link (a
        directory with [@toc_status hidden], a library) *)
  ; kind : string option
    (** what the entry links to, in odoc's words: ["leaf-page"], ["module"],
        ["source"], …; [None] for an entry that is not a link *)
  ; children : node list }

exception Missing of string

let is_blank c = c = ' ' || c = '\t' || c = '\n' || c = '\r'

(* the character an entity names: the ones odoc writes, and any numeric one *)
let entity name =
  let number s base =
    let digit c =
      match c with
      | '0' .. '9' -> true
      | 'a' .. 'f' | 'A' .. 'F' -> base = 16
      | _ -> false
    in
    if s <> "" && String.for_all digit s
    then
      match int_of_string_opt ((if base = 16 then "0x" else "") ^ s) with
      | Some c when Uchar.is_valid c -> Some (Uchar.of_int c)
      | _ -> None
    else None
  in
  match name with
  | "lt" -> Some (Uchar.of_char '<')
  | "gt" -> Some (Uchar.of_char '>')
  | "amp" -> Some (Uchar.of_char '&')
  | "quot" -> Some (Uchar.of_char '"')
  | "apos" -> Some (Uchar.of_char '\'')
  | "nbsp" -> Some (Uchar.of_int 0xA0)
  | _ -> (
    match String.length name with
    | n when n > 2 && name.[0] = '#' && (name.[1] = 'x' || name.[1] = 'X') ->
        number (String.sub name 2 (n - 2)) 16
    | n when n > 1 && name.[0] = '#' -> number (String.sub name 1 (n - 1)) 10
    | _ -> None)

(* [text html]: the plain text of the HTML fragment [html] odoc gives as an
   entry's content: tags dropped, entities decoded (an unknown one is kept as
   is), white space collapsed *)
let text html =
  let n = String.length html in
  let b = Buffer.create n in
  let rec go i =
    if i < n
    then
      match html.[i] with
      | '<' -> (
        match String.index_from_opt html i '>' with
        | Some j -> go (j + 1)
        | None -> ())
      | '&' -> (
          let decoded =
            Option.bind (String.index_from_opt html i ';') (fun j ->
              Option.map
                (fun u -> u, j)
                (entity (String.sub html (i + 1) (j - i - 1))))
          in
          match decoded with
          | Some (u, j) ->
              Buffer.add_utf_8_uchar b u;
              go (j + 1)
          | None ->
              Buffer.add_char b '&';
              go (i + 1))
      | c ->
          Buffer.add_char b (if is_blank c then ' ' else c);
          go (i + 1)
  in
  go 0;
  String.split_on_char ' ' (Buffer.contents b)
  |> List.filter (( <> ) "")
  |> String.concat " "

(* the directory of a path: "a/b.html" -> "a", "b.html" -> "" *)
let parent p =
  match String.rindex_opt p '/' with Some i -> String.sub p 0 i | None -> ""

let in_dir dir f = if dir = "" then f else dir ^ "/" ^ f
let is_index p = Filename.basename p = "index.html"

(* [rebase ~from ~onto url]: [url], a path below the directory [from], made a
   path below [onto]; [None] if [url] is not below [from] *)
let rebase ~from ~onto url =
  let url =
    if String.ends_with ~suffix:"/" url then url ^ "index.html" else url
  in
  if from = ""
  then Some (in_dir onto url)
  else
    let p = from ^ "/" in
    if String.starts_with ~prefix:p url
    then
      let n = String.length p in
      Some (in_dir onto (String.sub url n (String.length url - n)))
    else None

(* [of_json ~dir json]: the tree of a sidebar.json found in the directory [dir]
   of [src]. odoc writes the links relative to its HTML root, where the file's
   directory is the package's ([<pkg>/index.html] is the top entry): they are
   made relative to [src]. *)
let of_json ~dir json =
  let open Yojson.Safe.Util in
  let url j = to_string_option (member "url" (member "node" j)) in
  let entries = to_list json in
  let from =
    Option.value ~default:"" (Option.map parent (List.find_map url entries))
  in
  let rec node j =
    let entry = member "node" j in
    { label = text (to_string (member "content" entry))
    ; url = Option.bind (url j) (rebase ~from ~onto:dir)
    ; kind = to_string_option (member "kind" entry)
    ; children = List.map node (to_list (member "children" j)) }
  in
  List.map node entries

(* the sidebar.json for the page [page] of [src]: the first one in the page's
   directory or above it, up to [src], with the directory where it was found *)
let locate ~src page =
  let rec up dir =
    let f = Filename.concat src (in_dir dir "sidebar.json") in
    if Sys.file_exists f
    then Some (dir, f)
    else if dir = ""
    then None
    else up (parent dir)
  in
  up (parent page)

let has_sidebar ~src page = locate ~src page <> None

(* the directory an entry stands for, if it is one: a clickable directory links
   to its index page; one that odoc does not link ([@toc_status hidden]) is the
   directory its own entries are in *)
let rec dir n =
  match n.url with
  | Some p -> if is_index p then Some (parent p) else None
  | None -> List.find_map location n.children

(* the directory an entry is in *)
and location n =
  match n.url with
  | Some p when not (is_index p) -> Some (parent p)
  | _ -> Option.map parent (dir n)

(* [find page nodes]: the entry of the page [page] in the tree [nodes]: the
   entry linking to it or, for the index page of a directory that odoc does not
   link, the entry of that directory *)
let rec find page = function
  | [] -> None
  | n :: t -> (
      let matches =
        match n.url with
        | Some p -> p = page
        | None -> is_index page && dir n = Some (parent page)
      in
      if matches
      then Some n
      else
        match find page n.children with Some _ as r -> r | None -> find page t)

(* a manual entry: a page or a directory, holding manual entries only. After
   the manual, odoc lists each library of the package (an entry that is not a
   link, holding modules) and its rendered sources (a page holding source
   files): wodoc has its own API navigation. *)
let rec manual n =
  (match n.kind with None | Some ("page" | "leaf-page") -> true | _ -> false)
  && List.for_all manual n.children

let items ~src index =
  let fail fmt =
    Printf.ksprintf
      (fun m ->
         raise (Missing (Printf.sprintf "wodoc: (page-tree %s): %s" index m)))
      fmt
  in
  let file, tree =
    match locate ~src index with
    | None ->
        let where =
          match parent index with
          | "" -> src
          | d ->
              Printf.sprintf "%s or above it, up to %s" (Filename.concat src d)
                src
        in
        fail "no sidebar.json in %s (odoc_driver writes one for each package)"
          where
    | Some (dir, f) -> (
      try f, of_json ~dir (Yojson.Safe.from_file f) with
      | Yojson.Json_error m | Yojson.Safe.Util.Type_error (m, _) ->
          fail "%s: unexpected contents: %s" f m
      | Sys_error m -> fail "%s" m)
  in
  let root =
    match find index tree with
    | Some n -> n
    | None -> fail "%s does not show %s" file index
  in
  let rec item n =
    if not (manual n)
    then None
    else
      match List.filter_map item n.children, n.url with
      | [], None -> None
      | [], Some path ->
          Some (Config.Link {label = n.label; path; current = ""})
      | items, index -> Some (Config.Group {heading = n.label; index; items})
  in
  (match root.url with
    | Some path -> [Config.Link {label = root.label; path; current = ""}]
    | None -> [])
  @ List.filter_map item root.children
