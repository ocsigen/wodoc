(lang dune 3.0)

(name wodoc)

(cram enable)

;; wodoc.opam is hand-maintained (NOT generated): it carries a pin-depends on the
;; forked odoc family, which dune's (generate_opam_files) cannot emit. Keep the
;; package metadata (synopsis/description/depends) in sync there by hand.

(source
 (github ocsigen/wodoc))

(authors "The Ocsigen team")

(maintainers "The Ocsigen team")

(license MIT)
