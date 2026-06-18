`wodoc resolve-refs --hosted` rewrites cross-PROJECT references — the absolute
`https://ocaml.org/p/<pkg>/<v>/doc/<path>` links odoc_driver --remap emits for a
resolved dependency — into RELATIVE links to that project's docs deployed under
the shared Ocsigen root. Each hosted project declares its deployed layout.

A referrer page linking to several Ocsigen projects, one per layout, plus a
non-Ocsigen dependency (react) that must stay on ocaml.org:

  $ cat > page.html <<'HTML'
  > <a href="https://ocaml.org/p/js_of_ocaml/6.3.2/doc/Js_of_ocaml/Js/index.html#type-t">Js.t</a>
  > <a href="https://ocaml.org/p/js_of_ocaml-lwt/6.3.2/doc/Js_of_ocaml_lwt/index.html">jsoo-lwt</a>
  > <a href="https://ocaml.org/p/tyxml/4.6.0/doc/Html_sigs/module-type-T/index.html">tyxml</a>
  > <a href="https://ocaml.org/p/reactiveData/0.3/doc/ReactiveData/index.html">rd</a>
  > <a href="https://ocaml.org/p/eliom/12.0/doc/Eliom_content/index.html">eliom</a>
  > <a href="https://ocaml.org/p/react/1.2.2/doc/React/index.html">react</a>
  > HTML

  $ wodoc resolve-refs --relroot ../../.. --side server --self ocsigen-toolkit \
  >   --hosted js_of_ocaml=js_of_ocaml:subdir: \
  >   --hosted tyxml=tyxml:subdir: \
  >   --hosted reactiveData=reactiveData:root: \
  >   --hosted eliom=eliom:multilib:Eliom \
  >   page.html

A `subdir` project keeps its `<pkg>/` directory and odoc's nested module layout
verbatim; a sub-package (`js_of_ocaml-lwt`) matches the `js_of_ocaml` family
entry and deploys under its own `<pkg>/`. A `root` project puts modules at the
version root; a `multilib` one under `<dir>.<side>/`. react is not hosted, so it
keeps its ocaml.org link.

  $ cat page.html
  <a href="../../../js_of_ocaml/latest/js_of_ocaml/Js_of_ocaml/Js/index.html#type-t">Js.t</a>
  <a href="../../../js_of_ocaml/latest/js_of_ocaml-lwt/Js_of_ocaml_lwt/index.html">jsoo-lwt</a>
  <a href="../../../tyxml/latest/tyxml/Html_sigs/module-type-T/index.html">tyxml</a>
  <a href="../../../reactiveData/latest/ReactiveData/index.html">rd</a>
  <a href="../../../eliom/latest/eliom.server/Eliom_content/index.html">eliom</a>
  <a href="https://ocaml.org/p/react/1.2.2/doc/React/index.html">react</a>
