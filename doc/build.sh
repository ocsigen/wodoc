#!/bin/bash
# Build the themed wodoc documentation (manual + API) for ocsigen.org, from the
# CURRENT checkout. Produces one version directory ready to publish on wodoc's
# gh-pages (served at https://ocsigen.org/wodoc/).
#
# wodoc dogfoods itself: unless $WODOC is set, this builds the wodoc binary from
# this very checkout and uses it to theme its own documentation.
#
# Pipeline (see doc/README.md for the full picture):
#   1. dune build @doc   -> odoc HTML for the manual (manual/*.mld) AND the API
#                           of the wodoc library, in one run.
#   2. wodoc assemble    -> wrap every page in the Ocsigen site chrome
#                           (header/menu/drawer, version <select>, left nav).
#
# Links are version-relative via the {{base}} token; only the version <select> is
# absolute, via {{pub}} = /wodoc. The themed CSS is served centrally at
# /css/ocsigen-odoc.css by ocsigen.org.
#
# Usage: build.sh <label> [outdir]
#   label   version label / output subdir (e.g. dev, 0.1.0); NEVER "latest"
#   outdir  where to write <label>/ (default: _doc-site, gitignored)
#
#   WODOC   path to a prebuilt wodoc binary (default: build it from this checkout)
set -e

LABEL="$1"
[ -n "$LABEL" ] || { echo "usage: build.sh <label> [outdir]" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUTDIR="${2:-$ROOT/_doc-site}"
OUT="$OUTDIR/$LABEL"
PUB="${PUB:-/wodoc}"

cd "$ROOT"
# Dogfood: build wodoc with dune, then theme wodoc's own docs with that binary.
dune build @doc bin/main.exe
WODOC="${WODOC:-$ROOT/_build/default/bin/main.exe}"
[ -x "$WODOC" ] || { echo "wodoc binary not found at $WODOC" >&2; exit 1; }

SRC="$ROOT/_build/default/_doc/_html"
[ -d "$SRC/wodoc" ] || { echo "no wodoc package output in $SRC" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"

# Manual left-column nav, from the canonical menu kept here.
NAV_MANUAL="$(mktemp)"
python3 "$HERE/gen-manual-nav.py" "$HERE/menu.wiki" "{{base}}" >"$NAV_MANUAL"

# Version <select> options: every sibling version directory already published.
VERSIONS="$(mktemp)"
{
  echo "              <option value=\"latest\">latest</option>"
  for d in "$OUTDIR"/*/; do
    v="$(basename "$d")"
    [ "$v" = latest ] && continue
    echo "              <option value=\"$v\">$v</option>"
  done
  echo "              <option value=\"$LABEL\">$LABEL</option>"
} 2>/dev/null | awk '!seen[$0]++' >"$VERSIONS"

TMPL="$(mktemp)"
sed -e "/{{leftnav}}/r $HERE/leftnav.html" -e "/{{leftnav}}/d" "$HERE/template.html" \
  | sed -e "s#{{pub}}#$PUB#g" \
        -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
        -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
  >"$TMPL"

# Assemble every page across the wodoc package subtree, mirroring odoc's layout.
# Skip odoc's support dir and the top-level package-list index (replaced by a
# redirect below).
(cd "$SRC" && find . -name '*.html' -not -path './odoc.support/*') | while read -r page; do
  rel="${page#./}"
  [ "$rel" = "index.html" ] && continue
  slashes="${rel//[!\/]/}"; depth=${#slashes}
  if [ "$depth" -eq 0 ]; then base="."; else
    base=""; for _ in $(seq 1 "$depth"); do base="../$base"; done; base="${base%/}"
  fi
  mkdir -p "$OUT/$(dirname "$rel")"
  "$WODOC" assemble --template "$TMPL" --current "wodoc" --base "$base" \
    "$SRC/$rel" >"$OUT/$rel"
done

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# Version root -> package home (manual overview).
cat >"$OUT/index.html" <<EOF
<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<meta http-equiv="refresh" content="0; url=wodoc/index.html"/>
<link rel="canonical" href="wodoc/index.html"/>
<title>Wodoc documentation</title></head>
<body><p>Redirecting to the <a href="wodoc/index.html">Wodoc documentation</a>.</p></body>
</html>
EOF

SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/wodoc-highlight.js" "$OUT/wodoc-highlight.js"

echo "built wodoc $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
