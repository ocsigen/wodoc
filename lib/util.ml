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
