(* Wodoc.Preprocess.tree rewrites the {%wodoc:…%} markers of every .mld file
   below a directory: in subdirectories too, across a symbolic link back up the
   tree (walked once), past a dangling link (skipped), and only in .mld files. *)

let marker = "{%wodoc:x%}"
let rewritten = Wodoc.Preprocess.string marker

let () =
  let root = Filename.concat (Sys.getcwd ()) "preprocess-tree" in
  let path rel = Filename.concat root rel in
  ignore (Sys.command ("rm -rf " ^ Filename.quote root));
  Sys.mkdir root 0o755;
  Sys.mkdir (path "sub") 0o755;
  List.iter
    (fun f -> Wodoc.Util.write_file (path f) marker)
    ["top.mld"; "sub/deep.mld"; "sub/notes.txt"];
  Unix.symlink ".." (path "sub/loop");
  Unix.symlink "nowhere.mld" (path "dangling.mld");
  Wodoc.Preprocess.tree root;
  let expect f contents =
    let got = Wodoc.Util.read_file (path f) in
    if got <> contents
    then (
      Printf.eprintf "%s: expected %S, got %S\n" f contents got;
      exit 1)
  in
  expect "top.mld" rewritten;
  expect "sub/deep.mld" rewritten;
  expect "sub/notes.txt" marker
