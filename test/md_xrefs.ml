(* Wodoc.Resolve.markdown re-aims the links of a Markdown twin that cross a
   package boundary: odoc's Markdown backend makes them relative to its own
   output tree, one directory per package, and they lead nowhere once
   deployed. *)

let hosted =
  Wodoc.Resolve.
    [ "eliom", ("eliom", Multilib, "Eliom")
    ; "ocsigen-toolkit", ("ocsigen-toolkit", Multilib, "Ot")
    ; "ocsigenserver", ("ocsigenserver", Root, "Ocsigen")
    ; "tyxml", ("tyxml", Subdir, "Tyxml")
    ; "js_of_ocaml", ("js_of_ocaml", Subdir, "") ]

let failures = ref 0

let check name ~expected actual =
  if actual <> expected
  then (
    incr failures;
    Printf.printf "%s:\n  expected %S\n  got      %S\n" name expected actual)

(* A single-package build (eliom through odoc_driver): odoc's tree holds
   [eliom/…], deployed at the version root. *)
let eliom ?(versions = []) ?(version = "latest") ~src link =
  let out =
    String.sub src (String.length "eliom/")
      (String.length src - String.length "eliom/")
  in
  let drop t =
    String.sub t (String.length "eliom/")
      (String.length t - String.length "eliom/")
  in
  Wodoc.Resolve.markdown ~hosted ~versions ~version ~own:["eliom"]
    ~deployed:drop ~base:(Wodoc.Build.base_of out) ~src ~out
    (Printf.sprintf "see [x](%s)." link)

let link target = Printf.sprintf "see [x](%s)." target
let manual = "eliom/clientserver/html.md"
let api = "eliom/eliom.server/Eliom-Content.md"

let () =
  (* hosted projects, one per layout: their deployed Markdown twin *)
  check "subdir module"
    ~expected:(link "../../../tyxml/latest/tyxml/Tyxml_html.md#val-a")
    (eliom ~src:manual "./../../tyxml/tyxml/Tyxml_html.md#val-a");
  check "subdir manual page"
    ~expected:(link "../../../tyxml/latest/tyxml/ppx.md")
    (eliom ~src:manual "./../../tyxml/ppx.md");
  check "subdir family package"
    ~expected:
      (link "../../../js_of_ocaml/latest/js_of_ocaml-lwt/Js_of_ocaml_lwt.md")
    (eliom ~src:manual
       "./../../js_of_ocaml-lwt/js_of_ocaml-lwt/Js_of_ocaml_lwt.md");
  check "root manual page"
    ~expected:(link "../../../ocsigenserver/latest/config.md#section")
    (eliom ~src:manual "./../../ocsigenserver/config.md#section");
  check "root module"
    ~expected:(link "../../../ocsigenserver/latest/Ocsigen-Server.md")
    (eliom ~src:api "./../../ocsigenserver/ocsigenserver/Ocsigen-Server.md");
  check "multilib module"
    ~expected:
      (link "../../../ocsigen-toolkit/latest/ocsigen-toolkit.server/Ot-Popup.md")
    (eliom ~src:api "./../../ocsigen-toolkit/ocsigen-toolkit.server/Ot-Popup.md");
  check "a dev build links to the dev docs"
    ~expected:(link "../../../tyxml/dev/tyxml/ppx.md")
    (eliom ~version:"dev" ~src:manual "./../../tyxml/ppx.md");
  (* other packages: their documentation on ocaml.org, nested like the HTML *)
  check "ocaml.org module type, known version"
    ~expected:
      (link
         "https://ocaml.org/p/ocaml-compiler/5.4.0/doc/stdlib/Stdlib/Map/module-type-S/index.html#val-add")
    (eliom
       ~versions:["ocaml-compiler", "5.4.0"]
       ~src:api
       "./../../ocaml-compiler/stdlib/Stdlib-Map-module-type-S.md#val-add");
  check "ocaml.org functor argument and class, unknown version"
    ~expected:
      (link
         "https://ocaml.org/p/react/latest/doc/react/React/Make/argument-1-E/class-c/index.html")
    (eliom ~src:api "./../../react/react/React-Make-argument-1-E-class-c.md");
  check "operator anchor, escaped by odoc"
    ~expected:
      (link
         "https://ocaml.org/p/lwt/latest/doc/lwt/Lwt/Infix/index.html#val-\\(>>=\\)")
    (eliom ~src:api "./../../lwt/lwt/Lwt-Infix.md#val-\\(>>=\\)");
  check "ocaml.org manual page"
    ~expected:(link "https://ocaml.org/p/react/latest/doc/index.html")
    (eliom ~src:api "./../../react/index.md");
  (* left alone *)
  List.iter
    (fun target ->
       check ("unchanged " ^ target) ~expected:(link target)
         (eliom ~src:manual target))
    [ "./../server/state.md#scopes"
    ; "#anchor"
    ; "https://example.org/x.md"
    ; "/tyxml/"
    ; "./../../../outside/the/tree.md" ];
  check "fenced code"
    ~expected:
      "```\n[x](./../../tyxml/ppx.md)\n```\n[x](../../../tyxml/latest/tyxml/ppx.md)"
    (Wodoc.Resolve.markdown ~hosted ~versions:[] ~version:"latest"
       ~own:["eliom"] ~deployed:Fun.id ~base:".." ~src:manual
       ~out:"clientserver/html.md"
       "```\n[x](./../../tyxml/ppx.md)\n```\n[x](./../../tyxml/ppx.md)");
  (* A multi-package build whose main package is deployed at the version root
     (a manual-root project): a link from another of its packages is re-aimed
     at where the target now is, and a link that already reaches it is kept. *)
  let srv ~src ~out ~base target =
    Wodoc.Resolve.markdown ~hosted ~versions:[] ~version:"latest"
      ~own:["srv"; "srv-compat"]
      ~deployed:(fun t ->
        if String.starts_with ~prefix:"srv/" t
        then String.sub t 4 (String.length t - 4)
        else t)
      ~base ~src ~out (link target)
  in
  check "own package moved by the strip"
    ~expected:(link "../Srv-Ext-Conf.md#val-p")
    (srv ~src:"srv-compat/Srv_ext.md" ~out:"srv-compat/Srv_ext.md" ~base:".."
       "./../srv/Srv-Ext-Conf.md#val-p");
  check "own link already right" ~expected:(link "./Srv-Ext-Conf.md")
    (srv ~src:"srv/Srv-Ext.md" ~out:"Srv-Ext.md" ~base:"." "./Srv-Ext-Conf.md");
  (* the first version seen for each package *)
  check "versions from the HTML" ~expected:"ocaml-compiler=5.4.0 react=1.2.2"
    (String.concat " "
    @@ List.map (fun (p, v) -> p ^ "=" ^ v)
    @@ List.sort compare
    @@ Wodoc.Resolve.ocaml_org_versions
         {|<a href="https://ocaml.org/p/ocaml-compiler/5.4.0/doc/Stdlib/index.html">
<a href="https://ocaml.org/p/react/1.2.2/doc/React/index.html">
<a href="https://ocaml.org/p/react/9.9/doc/React/S/index.html">|}
    );
  if !failures > 0 then exit 1
