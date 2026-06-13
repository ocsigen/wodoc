`wodoc requalify-xrefs` fixes flat cross-project links to a WRAPPED library:
odoc_driver --remap names a reference to eliom's `Eliom.Content` by the flat path
`Eliom_content`, but the qualified eliom deploys it under its wrapper as
`Eliom/Content` (renamed) or `Eliom/Eliom_react` (kept name). The mapping is not
uniform, so the tool probes the co-located target tree and keeps the form that
exists.

Lay out a co-located site: a target project (eliom) deploying two modules under
its Eliom/ wrapper, and a referrer page linking to them by their flat names.

  $ mkdir -p site/eliom/latest/eliom.server/Eliom/Content/Html
  $ touch site/eliom/latest/eliom.server/Eliom/Content/Html/index.html
  $ mkdir -p site/eliom/latest/eliom.server/Eliom/Eliom_react
  $ touch site/eliom/latest/eliom.server/Eliom/Eliom_react/index.html
  $ mkdir -p site/ocsigen-toolkit/dev
  $ cat > site/ocsigen-toolkit/dev/page.html <<'HTML'
  > <a href="../../eliom/latest/eliom.server/Eliom_content/Html/index.html#type-elt">elt</a>
  > <a href="../../eliom/latest/eliom.server/Eliom_react/index.html">react</a>
  > HTML

  $ wodoc requalify-xrefs --site site --wrapped eliom=Eliom
  wodoc requalify-xrefs: rewrote 1 files

The renamed module is requalified to Eliom/Content; the kept-name one to
Eliom/Eliom_react (both probed, the existing form chosen):

  $ cat site/ocsigen-toolkit/dev/page.html
  <a href="../../eliom/latest/eliom.server/Eliom/Content/Html/index.html#type-elt">elt</a>
  <a href="../../eliom/latest/eliom.server/Eliom/Eliom_react/index.html">react</a>

It also handles a SINGLE-package manual-root project (modules at the version
root, e.g. ocsigenserver/<version>/Ocsigen_extensions) — not just the
<pkg>.<lib>/ layout. The wrapper-renamed module is requalified, a kept-name one
is left (it already resolves):

  $ mkdir -p site2/ocsigenserver/latest/Ocsigen/Extensions
  $ touch site2/ocsigenserver/latest/Ocsigen/Extensions/index.html
  $ mkdir -p site2/ocsigenserver/latest/Ocsigen_cookie_map
  $ touch site2/ocsigenserver/latest/Ocsigen_cookie_map/index.html
  $ mkdir -p site2/eliom/dev
  $ cat > site2/eliom/dev/p.html <<'HTML'
  > <a href="../../ocsigenserver/latest/Ocsigen_extensions/index.html">ext</a>
  > <a href="../../ocsigenserver/latest/Ocsigen_cookie_map/index.html">cm</a>
  > HTML
  $ wodoc requalify-xrefs --site site2 --wrapped ocsigenserver=Ocsigen
  wodoc requalify-xrefs: rewrote 1 files
  $ cat site2/eliom/dev/p.html
  <a href="../../ocsigenserver/latest/Ocsigen/Extensions/index.html">ext</a>
  <a href="../../ocsigenserver/latest/Ocsigen_cookie_map/index.html">cm</a>
