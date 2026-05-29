(lang dune 3.0)

(name wodoc)

(generate_opam_files true)

(source
 (github ocsigen/wodoc))

(authors "The Ocsigen team")

(maintainers "The Ocsigen team")

(license "LGPL-2.1-only WITH OCaml-LGPL-linking-exception")

(package
 (name wodoc)
 (synopsis "An odoc driver that builds complete styled websites from .mld/.mli")
 (description
  "wodoc (web + odoc) is an odoc driver. It extends odoc with backward-compatible\n\
   presentational markers ({%wodoc:...%}) for arbitrary CSS classes, containers\n\
   and layout, and adds a templating layer to assemble a full website (header,\n\
   menus, version selector). The markers use a custom raw-markup target that\n\
   stock odoc ignores, so the very same sources render as plain semantic\n\
   documentation (e.g. on ocaml.org) and as a full themed site with wodoc.\n\
   Usable by any OCaml project, not only Ocsigen.")
 (depends
  (ocaml
   (>= 4.08))
  (odoc
   (>= 3.0))))
