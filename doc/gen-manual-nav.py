#!/usr/bin/env python3
"""Build wodoc's manual left-column navigation from its wikicreole menu
(doc/menu.wiki). == / === headings become section labels; [[page|Title]] links
point at the manual pages, which odoc puts under the wodoc package
(<base>/wodoc/<page>.html). wodoc is a single package, so there is no a_api /
sibling-package handling to do (unlike the multi-package projects).

Usage: gen-manual-nav.py <menu.wiki> <base-url>
"""
import html
import re
import sys

menu, base = sys.argv[1], sys.argv[2]
PKG = "wodoc"  # package dir that carries both the manual pages and the API

out = ['<nav class="api-nav manual-nav">', "<h3>Manual</h3>"]
open_ul = False


def close():
    global open_ul
    if open_ul:
        out.append("</ul>")
        open_ul = False


def open_section():
    global open_ul
    if not open_ul:
        out.append('<ul class="api-section">')
        open_ul = True


for raw in open(menu):
    line = raw.rstrip("\n")
    m = re.match(r"^(=+)\s*(.*)$", line)
    if not m:
        continue
    level = len(m.group(1))  # number of '=' : the menu nesting depth
    text = m.group(2).strip()

    link = re.match(r"\[\[([^|\]]+)\|([^\]]+)\]\]", text)
    if link:
        page, title = link.group(1).strip(), link.group(2).strip()
        open_section()
        out.append(
            f'<li class="ml{level}" data-wodoc-page="{page}">'
            f'<a href="{base}/{PKG}/{page}.html">{html.escape(title)}</a></li>'
        )
    elif text and "<<" not in text and "[[" not in text:
        # a plain section heading (== Manual, == API); the level drives the left
        # indentation (see ocsigen-odoc.css .mlN)
        close()
        out.append(f'<h4 class="ml{level}">{html.escape(text)}</h4>')

close()
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
