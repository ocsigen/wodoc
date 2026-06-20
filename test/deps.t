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

A cross-package PAGE reference (`{!/pkg/page-x}`) odoc could not resolve renders
as an `xref-unresolved` span titled `/pkg/path`. It is rewritten to the project's
deployed manual page: at the version root for `multilib`/`root` projects, under
`<pkg>/` for a `subdir` one. A `.section` suffix becomes an anchor; a
non-hosted target keeps its span.

  $ cat > pages.html <<'HTML'
  > <span class="xref-unresolved" title="/eliom/server-services">services</span>
  > <span class="xref-unresolved" title="/ocsigenserver/config">config</span>
  > <span class="xref-unresolved" title="/tyxml/ppx">ppx syntax</span>
  > <span class="xref-unresolved" title="/eliom/server-state.scopes">scopes</span>
  > <span class="xref-unresolved" title="/nothosted/foo">other</span>
  > HTML

  $ wodoc resolve-refs --relroot ../../.. --side server --self ocsigen-toolkit \
  >   --hosted eliom=eliom:multilib:Eliom \
  >   --hosted ocsigenserver=ocsigenserver:root: \
  >   --hosted tyxml=tyxml:subdir: \
  >   pages.html

  $ cat pages.html
  <a href="../../../eliom/latest/server-services.html">services</a>
  <a href="../../../ocsigenserver/latest/config.html">config</a>
  <a href="../../../tyxml/latest/tyxml/ppx.html">ppx syntax</a>
  <a href="../../../eliom/latest/server-state.html#scopes">scopes</a>
  <span class="xref-unresolved" title="/nothosted/foo">other</span>

A RESOLVED cross-package reference to a manual PAGE (odoc emitted an absolute
`…/doc/<name>.html` with no '/') deploys like the page references above, not like
a module: at the version root for `multilib`/`root`, under `<pkg>/` for `subdir`.
Module pages (`<Mod>/…/index.html`) keep the module layout.

  $ cat > res.html <<'HTML'
  > <a href="https://ocaml.org/p/ocsigenserver/7.0/doc/config.html">cfg page</a>
  > <a href="https://ocaml.org/p/ocsigenserver/7.0/doc/Ocsigen_server/index.html">cfg mod</a>
  > <a href="https://ocaml.org/p/eliom/12.0/doc/server-services.html">srv page</a>
  > <a href="https://ocaml.org/p/eliom/12.0/doc/Eliom_content/index.html">srv mod</a>
  > <a href="https://ocaml.org/p/tyxml/4.6.0/doc/ppx.html">ppx page</a>
  > HTML

  $ wodoc resolve-refs --relroot ../../.. --side server --self x \
  >   --hosted ocsigenserver=ocsigenserver:root: \
  >   --hosted eliom=eliom:multilib:Eliom \
  >   --hosted tyxml=tyxml:subdir: \
  >   res.html

  $ cat res.html
  <a href="../../../ocsigenserver/latest/config.html">cfg page</a>
  <a href="../../../ocsigenserver/latest/Ocsigen_server/index.html">cfg mod</a>
  <a href="../../../eliom/latest/server-services.html">srv page</a>
  <a href="../../../eliom/latest/eliom.server/Eliom_content/index.html">srv mod</a>
  <a href="../../../tyxml/latest/tyxml/ppx.html">ppx page</a>
