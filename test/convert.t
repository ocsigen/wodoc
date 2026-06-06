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
  t {{:../tuto/basics.html}Tutorial}

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
  t {{:../tuto/basics.html}tuto}

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
  {%wodoc:aside class="wip"%}{b Work in progress}
  
  Incomplete.{%wodoc:end%}
  {%wodoc:aside class="concept"%}{b Concept: Summary}
  
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

A <<header|...>> wrapper becomes a <header> element (so e.g. section.docblock >
header CSS applies); the heading inside still becomes a heading, and the
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
  {%wodoc:header%}
  
  {0 Configuration file}
    
  
  {%wodoc:end%}
  
  Body text.









A <<|...>> comment is removed (pre-pass, before code protection) up to its
first UNescaped >>, exactly like html_of_wiki — even a commented-out code
example inside it is dropped, and a section heading that follows survives (it is
not swallowed). The ~>> inside the example is escaped, so it does not close the
comment; the code's own >> does.

  $ cat > comment.wiki <<'EOF'
  > Before.
  > <<|Commented-out example:
  > <<code language="ocaml"|let f = get () ~>>= fun y -> y>>
  > = After, this heading survives =
  > EOF
  $ wodoc convert comment.wiki
  Before.
  
  {0 After, this heading survives}








Two @@class@@ attribute markers on the same line (a leading class plus an image
carrying its own) must not be merged by a greedy match into one bogus
multi-section attribute spanning both.

  $ cat > attrs.wiki <<'WIKI'
  > @@class="centered"@@{{@@class="wide"@@files/x.svg|My alt}}
  > WIKI
  $ wodoc convert attrs.wiki
  {%wodoc:@ class="centered"%}{%wodoc:img class="wide" src="files/x.svg" alt="My alt"%}

A code block keeps escaped >> (~>>, used for OCaml >>= and camlp4 quotations):
the block does not close at the escaped >>, and the ~ is dropped in the output.

  $ cat > esc.wiki <<'WIKI'
  > <<code language="ocaml"|
  > let f x = get () ~>>= fun y -> <:t< a ~>> in f
  > >>
  > WIKI
  $ wodoc convert esc.wiki
  {@ocaml[
  let f x = get () >>= fun y -> <:t< a >> in f
  ]}

Wikicreole tables (|=header cell|, |data cell|) become odoc light tables; the
header-cell marker and unsupported per-cell @@class/@@colspan attributes are
dropped (odoc tables carry none), and a [[..|..]] link inside a cell keeps its
pipe out of the split.

  $ cat > table.wiki <<'WIKI'
  > |=@@class="row"@@First|@@colspan="3"@@Description one|
  > |=Second|See [[basics|the guide]] now|
  > WIKI
  $ wodoc convert table.wiki
  {t
   | First | Description one |
   | Second | See {{:basics.html}the guide} now |
  }
