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

let string s =
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
