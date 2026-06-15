
# Authoring: what survives on ocaml.org

The `{%wodoc:...%}` target is unknown to stock odoc, so it is **dropped** when the same sources are built with a stock odoc (for example on ocaml.org). This is the whole point — the docs stay clean and semantic there — but it means you must choose, per construct, whether something is *content* (must survive) or *presentation* (may vanish).


## The rule

- **Must be meaningful on ocaml.org → use native odoc** (never a dropped marker): links `{{:url}text}`, content images `{image:url}`, text, code, lists, tables, headings. These render identically with or without wodoc.
- **`{%wodoc:@ ...%}`** only adds attributes to a *native* element: the element (and its content) survives on ocaml.org, only the class is absent there.
- **Drop on ocaml.org → `{%wodoc:div/span/a/...%}`**: purely presentational wrappers and chrome (layout containers, whole-block clickable wrappers). The native content inside still survives on ocaml.org; only the shell disappears.
In particular, prefer **native links** so they keep working on ocaml.org; reserve `{%wodoc:a%}` for making a whole block clickable (which native odoc cannot express), keeping a native link inside when the target should remain reachable.


## Cross-project references

The manual you write here is also published on ocaml.org, so it must not contain links that only resolve on ocsigen.org:

- API of another package → a native odoc reference, e.g. `{!Lwt.t}`. odoc resolves it across packages on ocaml.org and our renderer redirects it to ocsigen.org.
- A manual or project page of another Ocsigen project → a **relative** link `../<project>/<page>.html` (correct on the final flat ocsigen.org layout).
- **Never** an absolute `https://ocsigen.org/…` or `/wodoc/…` link for content: the first does not resolve on ocaml.org and the second only exists during migration previews.
The **chrome** of the site template (header, menus) may stay absolute: it only exists on ocsigen.org.
