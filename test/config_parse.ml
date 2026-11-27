(* Wodoc.Config reads (odoc-driver …) as a list of packages, or as one quoted
   string: the list form used to be dropped, with no warning, and the project
   then built with dune build @doc. *)

let driver cfg =
  match Wodoc.Config.of_string cfg with
  | c -> c.odoc_driver
  | exception Wodoc.Sexp.Error m -> Some ("error: " ^ m)

let failures = ref 0

let check name ~expected actual =
  if actual <> expected
  then (
    incr failures;
    let show = Option.value ~default:"None" in
    Printf.printf "%s: expected %s, got %s\n" name (show expected) (show actual))

let variants =
  "(variants (variant server (lib p.server) (indexdoc none) (heading S) (wrapper P)))"

let () =
  check "list" ~expected:(Some "js_of_ocaml js_of_ocaml-lwt")
    (driver "(project p)\n(odoc-driver js_of_ocaml js_of_ocaml-lwt)");
  check "quoted string" ~expected:(Some "js_of_ocaml js_of_ocaml-lwt")
    (driver "(project p)\n(odoc-driver \"js_of_ocaml js_of_ocaml-lwt\")");
  check "atoms and a quoted string, extra spaces" ~expected:(Some "a b c")
    (driver "(project p)\n(odoc-driver a \" b  c \")");
  check "one package" ~expected:(Some "eliom")
    (driver "(project p)\n(odoc-driver eliom)");
  check "absent" ~expected:None (driver "(project p)");
  check "implied by variants" ~expected:(Some "p")
    (driver ("(project p)\n" ^ variants));
  check "variants keep an explicit list" ~expected:(Some "p p-extra")
    (driver ("(project p)\n(odoc-driver p p-extra)\n" ^ variants));
  if !failures > 0 then exit 1
