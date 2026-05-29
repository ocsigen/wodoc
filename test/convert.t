Cross-references: <<a_api ...>> and <<a_manual ...>> become odoc references.

  $ cat > refs.wiki <<'EOF'
  > See <<a_api|module Cors>> and <<a_api |val Ocsigen.Server.start>>.
  > Also <<a_api text="API documentation"|module Staticmod>>.
  > Chapter <<a_manual chapter="config"|Configuration>> and
  > <<a_manual chapter="config" fragment="upload"|configuration>>.
  > EOF
  $ wodoc convert refs.wiki
  See {!Cors} and {!Ocsigen.Server.start}.
  Also {{!Staticmod}API documentation}.
  Chapter {{!page-config}Configuration} and
  {{!page-config.upload}configuration}.

Single page title: a second top-level (=) heading is demoted to {1}, so a page
never emits two {0} headings.

  $ cat > two-titles.wiki <<'EOF'
  > =Accesscontrol=
  > = The accesscontrol extension =
  > ==Loading the extension==
  > EOF
  $ wodoc convert two-titles.wiki
  {0 Accesscontrol}
  {1 The accesscontrol extension}
  {1 Loading the extension}

No top-level heading: the first heading is promoted to the page title {0}.

  $ cat > no-title.wiki <<'EOF'
  > ==Installation==
  > ==Usage==
  > EOF
  $ wodoc convert no-title.wiki
  {0 Installation}
  {1 Usage}

A leading @@id anchor on a heading becomes an odoc heading label, so cross-page
fragment references resolve. The closing @@ is optional.

  $ cat > anchor.wiki <<'EOF'
  > = Title =
  > ==@@id="foo"@@ Section foo==
  > ===@@id='bar' Subsection bar===
  > EOF
  $ wodoc convert anchor.wiki
  {0 Title}
  {1:foo Section foo}
  {2:bar Subsection bar}

A title carried inside a <<header|...>> wrapper still becomes {0}, and the
<<outline>> extension is dropped.

  $ cat > header.wiki <<'EOF'
  > <<header |
  >   = Configuration file =
  >   <<outline>>
  > >>
  > 
  > Body text.
  > EOF
  $ wodoc convert header.wiki
  
  {0 Configuration file}
    
  
  
  Body text.




