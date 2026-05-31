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
  Chapter {{:config.html}Configuration} and
  {{:config.html#upload}configuration}.

a_api/a_manual with a side or project become direct links into the themed tree
(clickable from a standalone build), emitted as [[url|text]] so the inline pass
protects the URL; plain ones stay odoc references.

  $ cat > sides.wiki <<'EOF'
  > s <<a_api subproject="server"|module Eliom.Service>>
  > c <<a_api project="lwt"|module Lwt>>
  > p <<a_api|module Cors>>
  > t <<a_manual project="tuto" chapter="basics"|Tutorial>>
  > EOF
  $ wodoc convert sides.wiki
  s {{:../eliom.server/Eliom/Service/index.html}Eliom.Service}
  c {{:https://ocsigen.org/wodoc/lwt/latest/Lwt/index.html}Lwt}
  p {!Cors}
  t {{:https://ocsigen.org/tuto/basics.html}Tutorial}

With --api-side, a plain <<a_api|...>> links into that side, and a val/type goes
to its module's page with an odoc anchor (#val-x / #type-x).

  $ cat > plain.wiki <<'EOF'
  > m <<a_api|module Eliom.State>>
  > v <<a_api|val Eliom.Service.create>>
  > y <<a_api|type Eliom.Bus.t>>
  > EOF
  $ wodoc convert --api-side server plain.wiki
  m {{:../eliom.server/Eliom/State/index.html}Eliom.State}
  v {{:../eliom.server/Eliom/Service/index.html#val-create}Eliom.Service.create}
  y {{:../eliom.server/Eliom/Bus/index.html#type-t}Eliom.Bus.t}

With --odoc-refs (the manual built in the same odoc run as the API), a_api and
a_manual become native odoc references that resolve in that build; another
project's manual still gets an external link.

  $ cat > inpkg.wiki <<'EOF'
  > a <<a_api subproject="server"|module Eliom.Service>>
  > c <<a_manual chapter="clientserver-html" fragment="syntax"|the manual>>
  > t <<a_manual project="tuto" chapter="basics"|tuto>>
  > EOF
  $ wodoc convert --odoc-refs inpkg.wiki
  a {!Eliom.Service}
  c {{!page-"clientserver-html".syntax}the manual}
  t {{:https://ocsigen.org/tuto/basics.html}tuto}

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

A class on a code block (e.g. Eliom's server/client/shared) is kept as a wodoc
attribute marker on the resulting code block, so the side colouring applies.

  $ cat > codeclass.wiki <<'EOF'
  > <<code language="ocaml" class="server"|let () = run ()>>
  > EOF
  $ wodoc convert codeclass.wiki
  {%wodoc:@ class=server%}
  {@ocaml[let () = run ()]}

Block notes (<<wip>>, <<paragraph>>, <<concept title=..>>) become divs carrying
the wrapper name as class; a concept keeps its title as a bold lead.

  $ cat > notes.wiki <<'EOF'
  > <<wip|Incomplete.>>
  > <<concept title="Summary"|Eliom is multi-tier.>>
  > EOF
  $ wodoc convert notes.wiki
  {%wodoc:div class="wip"%}Incomplete.{%wodoc:end%}
  {%wodoc:div class="concept"%}{b Summary}
  
  Eliom is multi-tier.{%wodoc:end%}


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




