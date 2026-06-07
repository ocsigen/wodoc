# How the wodoc documentation is generated

The wodoc documentation published at <https://ocsigen.org/wodoc/> is built
entirely with **odoc** and themed with the Ocsigen site chrome by **wodoc
itself** — wodoc dogfoods its own turn-key `wodoc build` command. The same odoc
sources are also what ocaml.org renders.

## Sources

| What | Where | Format |
|---|---|---|
| Manual | [`manual/*.mld`](../manual) | odoc pages |
| Manual home / API overview | `manual/index.mld`, `manual/api.mld` | odoc pages |
| API | the `.mli` of the `wodoc` library | odoc comments (native `{!…}` refs) |
| Build configuration | [`doc/wodoc`](wodoc) | declarative S-expression (read by `Wodoc.Config`) |
| Shared site menu | [`doc/menu.html`](menu.html) | HTML fragment with holes (header, top menu, drawer) |

The manual is pure native odoc (no `{%wodoc:…%}` content markers): the
documentation is built by `dune build @doc`, which compiles the sources with a
stock odoc and so would drop any wodoc marker. wodoc here only adds the **chrome**
(the `assemble` pass). The `{%wodoc:…%}` examples that appear in the manual are
shown verbatim inside code blocks, as documentation.

The page template and the left-column navigation are **not** files here: `wodoc
build` generates them — the template from `Wodoc.Build`, the left navigation
(version selector, on-this-page, manual + API sections) from the `(nav …)`
stanza of [`doc/wodoc`](wodoc). The only HTML kept in this directory is the
shared menu ([`doc/menu.html`](menu.html)), reused by every project.

## Build

```
dune build bin/main.exe
_build/default/bin/main.exe build \
  --config doc/wodoc --out _doc-site/<label> --menu doc/menu.html --label <label>
```

e.g. `--label dev`. `wodoc build` runs `dune build @doc` itself (odoc HTML for
the manual `manual/*.mld` and the API of the `wodoc` library, in one run) and
then assembles every page of the `wodoc` package into the Ocsigen chrome
(header/menu/drawer from `doc/menu.html`, version `<select>`, left navigation
from `doc/wodoc`), shipping the highlight starter and the version redirect.

Output goes to `_doc-site/<label>/`, laid out to match
`https://ocsigen.org/wodoc/<label>/`. Internal links are version-relative (a
per-page relative `base`); only the version `<select>` is absolute (`pub` =
`/wodoc`, from the config). The themed stylesheet is served centrally at
`/css/ocsigen-odoc.css` by ocsigen.org.

To preview the themed pages locally (the chrome references the site's shared
`/css//img/` assets by absolute path), add `--local` with an http(s) `--menu`
URL: it fetches those assets next to the output so a static server can serve
them. See `wodoc build --help` / the [Commands](../manual/commands.mld) manual.

## Deployment (CI)

[`.github/workflows/doc.yml`](../.github/workflows/doc.yml) builds and publishes
to the project's **`gh-pages`** branch (served at `ocsigen.org/wodoc/`):

- **push to `master`** → rebuilds and deploys the **`dev`** docs (`dev/`).
- **manual run** (Actions → *Documentation* → *Run workflow*) → builds any
  version. For a release: set *label* to the version (e.g. `0.1.0`), *ref* to the
  tag, and tick *set_latest* to repoint `latest`.

Each run replaces only its own `<label>/` directory; the other version
directories already on `gh-pages` are preserved.
