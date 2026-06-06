# How the wodoc documentation is generated

The wodoc documentation published at <https://ocsigen.org/wodoc/> is built
entirely with **odoc** and themed with the Ocsigen site chrome by **wodoc
itself** — wodoc dogfoods its own driver. The same odoc sources are also what
ocaml.org renders.

## Sources

| What | Where | Format |
|---|---|---|
| Manual | [`manual/*.mld`](../manual) | odoc pages |
| Manual home / API overview | `manual/index.mld`, `manual/api.mld` | odoc pages |
| API | the `.mli` of the `wodoc` library | odoc comments (native `{!…}` refs) |
| Left-column navigation | [`doc/menu.wiki`](menu.wiki) | wikicreole (nav only) |
| Theme / chrome | [`doc/template.html`](template.html), [`doc/leftnav.html`](leftnav.html) | HTML with `{{holes}}` |

The manual is pure native odoc (no `{%wodoc:…%}` content markers): the per-project
documentation is built by `dune build @doc`, which compiles the sources with a
stock odoc and so would drop any wodoc marker. wodoc here only adds the **chrome**
(the `assemble` pass). The `{%wodoc:…%}` examples that appear in the manual are
shown verbatim inside code blocks, as documentation.

## Build

```
doc/build.sh <label> [outdir]   # e.g. doc/build.sh dev
```

`doc/build.sh` dogfoods wodoc: unless `$WODOC` points at a prebuilt binary, it
builds wodoc from this checkout (`dune build`) and uses it to theme wodoc's own
documentation. It then:

1. `dune build @doc` — odoc HTML for the manual (`manual/*.mld`) and the API of
   the `wodoc` library, in one run, into `_build/default/_doc/_html/`.
2. `wodoc assemble` — wraps every page in the Ocsigen chrome (header, menu,
   drawer, version `<select>`, left navigation from `doc/menu.wiki`).

Output goes to `<outdir>/<label>/` (default `_doc-site/<label>/`), laid out to
match `https://ocsigen.org/wodoc/<label>/`. Internal links are version-relative
(the `{{base}}` token); only the version `<select>` is absolute (`{{pub}}` =
`/wodoc`). The themed stylesheet is served centrally at `/css/ocsigen-odoc.css`
by ocsigen.org.

## Deployment (CI)

[`.github/workflows/doc.yml`](../.github/workflows/doc.yml) builds and publishes
to the project's **`gh-pages`** branch (served at `ocsigen.org/wodoc/`):

- **push to `master`** → rebuilds and deploys the **`dev`** docs (`dev/`).
- **manual run** (Actions → *Documentation* → *Run workflow*) → builds any
  version. For a release: set *label* to the version (e.g. `0.1.0`), *ref* to the
  tag, and tick *set_latest* to repoint `latest`.

Each run replaces only its own `<label>/` directory; the other version
directories already on `gh-pages` are preserved.
