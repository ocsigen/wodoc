let read_file f =
  let ic = open_in_bin f in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let write_file f s =
  let oc = open_out_bin f in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc s; close_out oc)

let is_url p =
  String.starts_with ~prefix:"http://" p
  || String.starts_with ~prefix:"https://" p

(* [Sys_error] is ignored: another process may create [dir] between the test and
   the [mkdir]; a real failure surfaces when the caller writes into [dir]. *)
let rec mkdir_p dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir)
  then (
    mkdir_p (Filename.dirname dir);
    try Sys.mkdir dir 0o755 with Sys_error _ -> ())

let files dir =
  (* the directories already walked, by device and inode: a symbolic link back
     up the tree is not followed twice *)
  let seen = Hashtbl.create 16 in
  let skip f msg = Printf.eprintf "wodoc: skipping %s: %s\n" f msg in
  let rec walk rel =
    let f = if rel = "" then dir else Filename.concat dir rel in
    match Unix.stat f with
    | {Unix.st_kind = Unix.S_DIR; st_dev; st_ino; _} ->
        if Hashtbl.mem seen (st_dev, st_ino)
        then []
        else (
          Hashtbl.add seen (st_dev, st_ino) ();
          match Sys.readdir f with
          | entries ->
              Array.sort compare entries;
              List.concat_map
                (fun e -> walk (if rel = "" then e else Filename.concat rel e))
                (Array.to_list entries)
          | exception Sys_error msg -> skip f msg; [])
    | {Unix.st_kind = Unix.S_REG; _} -> if rel = "" then [] else [rel]
    | _ -> []
    | exception Unix.Unix_error (e, _, _) ->
        skip f (Unix.error_message e);
        []
  in
  match Unix.stat dir with
  | {Unix.st_kind = Unix.S_DIR; _} -> walk ""
  | _ | (exception Unix.Unix_error _) -> []
