// odoc emits manual code blocks as <pre class="language-...">; start odoc's
// bundled highlight.js once the page is ready. wodoc's own manual only uses
// plain OCaml and verbatim text blocks, so no extra grammar tweaks are needed
// (unlike e.g. js_of_ocaml, which teaches highlight.js its ppx syntax here).
(function () {
  if (!window.hljs) return;
  if (document.readyState === "loading")
    document.addEventListener("DOMContentLoaded", function () {
      hljs.highlightAll();
    });
  else hljs.highlightAll();
})();
