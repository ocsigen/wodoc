let mopen = "{%wodoc:"
let mclose = "%}"

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

let kind_of_tag = function
  | "val" | "value" -> Some "val"
  | "type" -> Some "type"
  | "exception" -> Some "exception"
  | _ -> None

(* The anchor kind of a reference target: odoc anchors these members as
   [#type-t], [#val-x], [#exception-E]. The kind is the tag of the last
   component ([M.type-t], [type-t]), or the old-style prefix of the whole
   target ([type:M.t]). [None] for an untagged target, or a tag that names no
   such member (a module, a page, a section). *)
let anchor_kind target =
  match String.index_opt target ':' with
  | Some i
    when i > 0
         && String.for_all
              (fun c -> c >= 'a' && c <= 'z')
              (String.sub target 0 i) ->
      kind_of_tag (String.sub target 0 i)
  | _ -> (
      (* the dots of an operator name ([val-(+.)]) do not separate components *)
      let stop =
        match String.index_opt target '(' with
        | Some p -> p
        | None -> String.length target
      in
      let last =
        match String.rindex_from_opt target (stop - 1) '.' with
        | Some i -> String.sub target (i + 1) (String.length target - i - 1)
        | None -> target
      in
      match String.index_opt last '-' with
      | None -> None
      | Some i -> kind_of_tag (String.sub last 0 i))

let ref_marker kind = "{%html:<!--wodoc:ref " ^ kind ^ "-->%}"
let is_space = function ' ' | '\t' | '\n' | '\r' -> true | _ -> false

let mark_ref_kinds s =
  let len = String.length s in
  let out = Buffer.create (len + 64) in
  let starts_with p i =
    i + String.length p <= len && String.sub s i (String.length p) = p
  in
  (* [p] at [i], followed by white space: odoc's [{v], [{m] and [{math] *)
  let opens p i =
    let e = i + String.length p in
    starts_with p i && e < len && is_space s.[e]
  in
  (* a backslash escapes only these characters *)
  let escape i =
    s.[i] = '\\' && i + 1 < len && String.contains "{}[]@" s.[i + 1]
  in
  (* the index just past the first [close] at or after [i], or [len] *)
  let past close i =
    match find s close i with Some j -> j + String.length close | None -> len
  in
  (* the index just past the [close] matching an [opening] before [i]: inline
     code brackets and math braces nest *)
  let rec past_nested opening close depth i =
    if i >= len
    then len
    else if escape i
    then past_nested opening close depth (i + 2)
    else if s.[i] = opening
    then past_nested opening close (depth + 1) (i + 1)
    else if s.[i] = close
    then
      if depth = 0 then i + 1 else past_nested opening close (depth - 1) (i + 1)
    else past_nested opening close depth (i + 1)
  in
  (* a marker that a previous run already put there is not doubled: the build
     preprocesses installed pages in place, on every run *)
  let add_marker kind =
    let m = ref_marker kind in
    let bl = Buffer.length out and ml = String.length m in
    if not (bl >= ml && Buffer.sub out (bl - ml) ml = m)
    then Buffer.add_string out m
  in
  let rec go i =
    if i < len
    then
      let copy_to j =
        let j = min j len in
        Buffer.add_substring out s i (j - i);
        go j
      in
      if escape i
      then copy_to (i + 2)
      else if starts_with "{[" i || starts_with "{@" i
      then copy_to (past "]}" (i + 2))
      else if opens "{v" i
      then copy_to (past "v}" (i + 2))
      else if opens "{m" i || opens "{math" i
      then copy_to (past_nested '{' '}' 0 (i + 2))
      else if starts_with "{%" i
      then copy_to (past "%}" (i + 2))
      else if starts_with "{!" i || starts_with "{{!" i
      then (
        let target = if s.[i + 1] = '{' then i + 3 else i + 2 in
        (match String.index_from_opt s target '}' with
        | Some e ->
            Option.iter add_marker
              (anchor_kind (String.sub s target (e - target)))
        | None -> ());
        copy_to target)
      else if s.[i] = '['
      then copy_to (past_nested '[' ']' 0 (i + 1))
      else copy_to (i + 1)
  in
  go 0; Buffer.contents out

let directives s =
  let out = Buffer.create (String.length s) in
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
            let directive = String.sub s cstart (cend - cstart) in
            Buffer.add_string out "{%html:<!--wodoc:";
            Buffer.add_string out directive;
            Buffer.add_string out "-->%}";
            i := cend + String.length mclose)
  done;
  Buffer.contents out

let string s = directives (mark_ref_kinds s)

let tree root =
  (* the directories already walked, by device and inode: a symbolic link back
     up the tree is not followed twice *)
  let seen = Hashtbl.create 16 in
  let skip f e =
    Printf.eprintf "wodoc: skipping %s: %s\n" f (Unix.error_message e)
  in
  let rec walk dir =
    let entries = Sys.readdir dir in
    Array.sort compare entries;
    Array.iter
      (fun e ->
         let f = Filename.concat dir e in
         match Unix.stat f with
         | {Unix.st_kind = Unix.S_DIR; st_dev; st_ino; _} ->
             if not (Hashtbl.mem seen (st_dev, st_ino))
             then (
               Hashtbl.add seen (st_dev, st_ino) ();
               walk f)
         | {Unix.st_kind = Unix.S_REG; _} when Filename.check_suffix e ".mld" ->
             let s = Util.read_file f in
             let out = string s in
             if out <> s then Util.write_file f out
         | _ -> ()
         | exception Unix.Unix_error (e, _, _) -> skip f e)
      entries
  in
  let {Unix.st_dev; st_ino; _} = Unix.stat root in
  Hashtbl.add seen (st_dev, st_ino) ();
  walk root
