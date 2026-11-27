odoc renders a reference it cannot resolve (one into another project) with its
path but without its kind: `{!M.type-t}` and `{!M.val-t}` both give a span
titled `M.t`. wodoc carries the kind from the source to the link through a
sentinel.

The preprocessor puts a marker before each reference whose last component is
tagged with the kind of a module member (`val-`, `value-`, `type-`,
`exception-`). Untagged references, other tags, and anything in code, verbatim,
raw markup or inline code are left alone:

  $ cat > refs.mld <<'EOF'
  > {0 Refs}
  > 
  > A {{!Eliom.Form.type-param}type}, a {!Js.val-x}, a {!M.value-y}, an
  > {!M.exception-Err}, a {!type-t}, a {!M.N.module-O}, a {!M.t},
  > a {{!/eliom/page-intro}page}, [{!M.type-a}] and \{!M.type-b}.
  > 
  > {[ let _ = "{!M.type-c}" ]}
  > 
  > {@ocaml[ let _ = "{!M.type-d}" ]}
  > 
  > {v {!M.type-e} v}
  > 
  > {%html:<b>{!M.type-f}</b>%} {%wodoc:div class=x%}{!M.type-g}{%wodoc:end%}
  > EOF
  $ wodoc preprocess refs.mld
  {0 Refs}
  
  A {%html:<!--wodoc:ref type-->%}{{!Eliom.Form.type-param}type}, a {%html:<!--wodoc:ref val-->%}{!Js.val-x}, a {%html:<!--wodoc:ref val-->%}{!M.value-y}, an
  {%html:<!--wodoc:ref exception-->%}{!M.exception-Err}, a {%html:<!--wodoc:ref type-->%}{!type-t}, a {!M.N.module-O}, a {!M.t},
  a {{!/eliom/page-intro}page}, [{!M.type-a}] and \{!M.type-b}.
  
  {[ let _ = "{!M.type-c}" ]}
  
  {@ocaml[ let _ = "{!M.type-d}" ]}
  
  {v {!M.type-e} v}
  
  {%html:<b>{!M.type-f}</b>%} {%html:<!--wodoc:div class=x-->%}{%html:<!--wodoc:ref type-->%}{!M.type-g}{%html:<!--wodoc:end-->%}

The old-style prefix (`{!type:M.t}`) names the kind too, and the dots of an
operator name do not hide its tag. Math is not code, a media element is not
verbatim, so neither hides the references that follow. A backslash only
escapes markup characters: in `\\{!M.type-u}`, odoc reads a backslash then an
escaped brace, not a reference, and so does the preprocessor:

  $ cat > more.mld <<'EOF'
  > {!type:M.t} {{!val:M.x}x} {!M.val-(+.)} {m [0,1)} {video:a.mp4} \\{!M.type-u}
  > EOF
  $ wodoc preprocess more.mld
  {%html:<!--wodoc:ref type-->%}{!type:M.t} {%html:<!--wodoc:ref val-->%}{{!val:M.x}x} {%html:<!--wodoc:ref val-->%}{!M.val-(+.)} {m [0,1)} {video:a.mp4} \\{!M.type-u}

The build preprocesses installed pages in place, on every run: a second pass
adds nothing.

  $ wodoc preprocess refs.mld > once.mld
  $ wodoc preprocess once.mld | diff once.mld -

odoc keeps the marker as an HTML comment, right before the reference. The
rendering pass turns it into a sentinel for the resolver:

  $ cat > odoc.html <<'EOF'
  > <p>A <!--wodoc:ref type--><span class="xref-unresolved" title="Eliom.Form.param">type</span>.</p>
  > EOF
  $ wodoc render odoc.html
  <p>A <!--wodoc-ref:type--><span class="xref-unresolved" title="Eliom.Form.param">type</span>.</p>

The resolver uses the kind for the anchor. Without a sentinel, a lowercase name
is still taken for a value. A sentinel left unused stays in the page; the build
strips them all once both resolver passes are done:

  $ cat > deps.html <<'EOF'
  > <!--wodoc-ref:type--><span class="xref-unresolved" title="Eliom.Form.param">param</span>
  > <!--wodoc-ref:val--><span class="xref-unresolved" title="Eliom.Form.input">input</span>
  > <!--wodoc-ref:exception--><span class="xref-unresolved" title="Eliom.Common.Eliom_404">404</span>
  > <span class="xref-unresolved" title="Eliom.Form.param">no sentinel</span>
  > <!--wodoc-ref:type--><span class="xref-unresolved" title="Nothosted.t">other</span>
  > EOF
  $ wodoc resolve-refs --relroot ../.. --self tuto \
  >   --hosted eliom=eliom:multilib:Eliom deps.html
  $ cat deps.html
  <a href="../../eliom/latest/eliom.server/Eliom/Form/index.html#type-param">param</a>
  <a href="../../eliom/latest/eliom.server/Eliom/Form/index.html#val-input">input</a>
  <a href="../../eliom/latest/eliom.server/Eliom/Common/index.html#exception-Eliom_404">404</a>
  <a href="../../eliom/latest/eliom.server/Eliom/Form/index.html#val-param">no sentinel</a>
  <!--wodoc-ref:type--><span class="xref-unresolved" title="Nothosted.t">other</span>

The same holds for a sibling package, whether odoc rendered the reference as a
span (it had a label) or as bare code (it had none):

  $ cat > siblings.html <<'EOF'
  > <!--wodoc-ref:type--><span class="xref-unresolved" title="Lwt_react.S.t">t</span>
  > <!--wodoc-ref:type--><code>Lwt_react.S.u</code>
  > <code>Lwt_react.S.v</code>
  > EOF
  $ wodoc resolve-refs --base .. --sibling Lwt_react=lwt_react/Lwt_react \
  >   siblings.html
  $ cat siblings.html
  <a href="../lwt_react/Lwt_react/S/index.html#type-t">t</a>
  <a href="../lwt_react/Lwt_react/S/index.html#type-u"><code>Lwt_react.S.u</code></a>
  <a href="../lwt_react/Lwt_react/S/index.html#val-v"><code>Lwt_react.S.v</code></a>
