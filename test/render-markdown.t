odoc's Markdown backend passes raw markup through verbatim, so the twins reach
wodoc carrying the same `<!--wodoc:...-->` markers as the HTML. Markdown has
neither containers nor classes, so those are dropped; the two directives that
carry content are kept instead.

Presentational containers vanish, content stays:

  $ cat > pres.md <<'EOF'
  > <!--wodoc:section class=docblock--> <!--wodoc:header-->
  > # Title
  > <!--wodoc:end-->
  > <!--wodoc:@ class=server-code-->
  > Some prose.
  > <!--wodoc:end-->
  > EOF
  $ wodoc render --markdown pres.md
  # Title
  
  Some prose.

An image is a Markdown image rather than a lost line. Without a `src` there is
nothing to show, so the marker just goes:

  $ printf '<!--wodoc:img src="shot.png" alt="A screenshot"-->\n<!--wodoc:img class=x-->\n' > img.md
  $ wodoc render --markdown img.md
  ![A screenshot](shot.png)

A link around a whole block is something Markdown cannot express, so its target
is carried over to the block's first heading:

  $ cat > card.md <<'EOF'
  > <!--wodoc:a class=card href=/eliom/--><!--wodoc:div class=inner-->
  > 
  > ### Eliom
  > 
  > Write client and server as one program.
  > 
  > <!--wodoc:end--><!--wodoc:end-->
  > EOF
  $ wodoc render --markdown card.md
  ### [Eliom](/eliom/)
  
  Write client and server as one program.

A block with no heading but a single line of content (a sponsor logo, say) is
wrapped whole, so the link survives there too:

  $ printf '<!--wodoc:a href=https://example.com-->\n<!--wodoc:img src="/l.svg" alt="Corp"-->\n<!--wodoc:end-->\n' > logo.md
  $ wodoc render --markdown logo.md
  [![Corp](/l.svg)](https://example.com)

A block that is neither has nowhere to carry the target, and is left alone
rather than mangled:

  $ cat > multi.md <<'EOF'
  > <!--wodoc:a href=/x/-->
  > One line.
  > 
  > Another paragraph.
  > <!--wodoc:end-->
  > EOF
  $ wodoc render --markdown multi.md
  One line.
  
  Another paragraph.

Dropping a marker empties the line it sat on, so runs of blank lines collapse to
one. Inside fenced code a blank line is content, and is kept:

  $ printf 'A\n\n\n\n\nB\n\n```\nx\n\n\n\ny\n```\n' > blanks.md
  $ wodoc render --markdown blanks.md
  A
  
  B
  
  ```
  x
  
  
  
  y
  ```
