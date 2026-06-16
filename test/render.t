The @ directive injects attributes into the next element. The multi-section
form "S0 | S1 | S2" descends into the first child at each level; an optional
leading index selects the Nth sibling at that level instead of the first.

A class on the table, a row and a cell (all the first ones) — the historical
@@a@b@c@@ behaviour:

  $ cat > t.html <<'EOF'
  > <p><!--wodoc:@ class=t | class=r | class=c--></p>
  > <table><tr><td>a1</td></tr><tr><td>b1</td></tr></table>
  > EOF
  $ wodoc render t.html
  
  <table class="t"><tr class="r"><td class="c">a1</td></tr><tr><td>b1</td></tr></table>


An index selects another row — here the 2nd:

  $ cat > row2.html <<'EOF'
  > <p><!--wodoc:@ class=pricing | 2 class=highlight--></p>
  > <table><tr><td>a1</td><td>a2</td></tr><tr><td>b1</td><td>b2</td></tr></table>
  > EOF
  $ wodoc render row2.html
  
  <table class="pricing"><tr><td>a1</td><td>a2</td></tr><tr class="highlight"><td>b1</td><td>b2</td></tr></table>


Indices compose across levels — the 3rd cell of the 2nd row. Empty sections
descend/select without styling:

  $ cat > cell.html <<'EOF'
  > <p><!--wodoc:@ | 2 | 3 class=hot--></p>
  > <table><tr><td>a1</td><td>a2</td><td>a3</td></tr><tr><td>b1</td><td>b2</td><td>b3</td></tr></table>
  > EOF
  $ wodoc render cell.html
  
  <table><tr><td>a1</td><td>a2</td><td>a3</td></tr><tr><td>b1</td><td>b2</td><td class="hot">b3</td></tr></table>


Several classes, HTML-style, need quotes (spaces separate them); they merge with
any class odoc already put on the element:

  $ cat > multi.html <<'EOF'
  > <p><!--wodoc:@ class="pricing wide"--></p>
  > <table class="odoc-table"><tr><td>a</td></tr></table>
  > EOF
  $ wodoc render multi.html
  
  <table class="odoc-table pricing wide"><tr><td>a</td></tr></table>


Sibling skipping respects nesting: a table nested inside the first row's cell is
skipped as a whole, so index 2 reaches the real second row:

  $ cat > nested.html <<'EOF'
  > <p><!--wodoc:@ | 2 class=out--></p>
  > <table><tr><td><table><tr><td>x</td></tr></table></td></tr><tr><td>real2</td></tr></table>
  > EOF
  $ wodoc render nested.html
  
  <table><tr><td><table><tr><td>x</td></tr></table></td></tr><tr class="out"><td>real2</td></tr></table>



The blog-latest directive is a widget, not presentational markup: render passes
it through as a stable hyphen-form sentinel (which this scanner, keyed on the
colon form, then ignores), for the build layer to substitute with the post list:

  $ cat > blog.html <<'XEOF'
  > <p><!--wodoc:blog-latest--></p>
  > XEOF
  $ wodoc render blog.html
  <p><!--wodoc-blog-latest--></p>


odoc_driver links each declaration to its rendered implementation with an
<a class="source_link">Source</a>; wodoc does not assemble those (empty) source
pages, so the dead links are stripped:

  $ cat > src.html <<'XEOF'
  > <a href="../../src/lib/x.ml.html#val-foo" class="source_link">Source</a><code>val foo : int</code>
  > XEOF
  $ wodoc render src.html
  <code>val foo : int</code>
