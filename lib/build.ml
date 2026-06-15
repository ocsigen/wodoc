(* Turn-key site build from a declarative {!Config}: assemble a whole odoc HTML
   tree into the themed Ocsigen site, with the shared menu, the generated
   left-navigation (from the config, replacing menu.wiki) and cross-reference
   resolution — the OCaml replacement for a project's build.sh. *)

let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let write_file f s =
  let oc = open_out_bin f in
  output_string oc s; close_out oc

let is_url p =
  String.starts_with ~prefix:"http://" p
  || String.starts_with ~prefix:"https://" p

(* "https://host" from "https://host/path…" (the site origin of a URL) *)
let origin_of url =
  match Str.search_forward (Str.regexp "://") url 0 with
  | exception Not_found -> None
  | i -> (
    match String.index_from_opt url (i + 3) '/' with
    | Some j -> Some (String.sub url 0 j)
    | None -> Some url)

(* the shared menu is given either as a local file or an http(s) URL (the single
   canonical copy lives in ocsigen.github.io); fetch the URL with curl. *)
let read_menu m =
  if not (is_url m)
  then read_file m
  else
    let tmp = Filename.temp_file "wodoc-menu" ".html" in
    let rc =
      Sys.command
        (Printf.sprintf "curl -fsSL %s -o %s" (Filename.quote m)
           (Filename.quote tmp))
    in
    if rc <> 0
    then (
      Sys.remove tmp;
      failwith ("wodoc build: cannot fetch menu " ^ m));
    let s = read_file tmp in
    Sys.remove tmp; s

let rec mkdir_p dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir)
  then (
    mkdir_p (Filename.dirname dir);
    try Sys.mkdir dir 0o755 with Sys_error _ -> ())

(* relative .html files under [root]/[sub], as "sub/...": odoc's page tree *)
let html_files root sub =
  let acc = ref [] in
  let rec walk rel =
    let abs = Filename.concat root rel in
    if Sys.is_directory abs
    then Array.iter (fun e -> walk (Filename.concat rel e)) (Sys.readdir abs)
    else if Filename.check_suffix rel ".html"
    then acc := rel :: !acc
  in
  if Sys.file_exists (Filename.concat root sub) then walk sub;
  List.sort compare !acc

(* "." / ".." / "../.." … : relative path from a page at depth [d] to the root *)
let base_of rel =
  let d = String.fold_left (fun n c -> if c = '/' then n + 1 else n) 0 rel in
  if d = 0
  then "."
  else String.concat "/" (List.init d (fun _ -> "..")) |> fun s -> s

let replace_hole template key value =
  Str.global_replace (Str.regexp_string ("{{" ^ key ^ "}}")) value template

let esc = Resolve.html_escape

(* The default highlight starter wodoc ships. It teaches odoc's bundled
   highlight.js the OCaml syntax extensions used across the Ocsigen projects, so
   ANY project's manual can show eliom, lwt or js_of_ocaml code with the right
   colours — no per-project file needed. A project with yet another syntax can
   still override the whole starter via (highlight <file>) in its config. *)
let default_highlight =
  {hl|// wodoc default syntax-highlight starter: start odoc's bundled highlight.js and
// teach it the OCaml extensions used across Ocsigen, so any doc can colour them:
//   - eliom:       let%client / %server / %shared (per-side colour), ~%x injection
//   - lwt:         let%lwt / match%lwt / … and the let* / and* / let+ operators
//   - js_of_ocaml: object%js / [%js] / … and the obj##meth / obj##.prop operators
//   - the name bound by let / and (function names)
(function () {
  var oc = window.hljs && hljs.getLanguage && hljs.getLanguage("ocaml");
  if (oc && oc.contains) {
    var rules = [];
    var lead = "(?:let|and|val|module|open|include|method|class|type|exception|fun)";
    // eliom: whole `let%client` (etc.) and bare `%client` -> per-side colour
    ["client", "server", "shared"].forEach(function (s) {
      rules.push({ className: "eliom-" + s, begin: new RegExp("\\b" + lead + "%" + s + "\\b") });
    });
    ["client", "server", "shared"].forEach(function (s) {
      rules.push({ className: "eliom-" + s, begin: new RegExp("%" + s + "\\b") });
    });
    // lwt: let*, and*, let+, and+ binding operators
    rules.push({ className: "keyword", begin: /\b(let|and)[*+]/ });
    // js_of_ocaml: obj##meth, obj##.prop
    rules.push({ className: "operator", begin: /##\.?/ });
    // eliom: ~%x client-value injection
    rules.push({ className: "subst", begin: /~%[A-Za-z_][\w']*/ });
    // any other ppx extension (%lwt, %js, %rpc, …) -- LAST so the specific rules win
    rules.push({ className: "keyword", begin: /%[a-z]+/ });
    oc.contains.unshift.apply(oc.contains, rules);
    // the name bound by let / let%x / let* / and -> a function/title (lookbehind
    // may be unsupported on old browsers; guard so the rest still applies)
    try {
      oc.contains.unshift({
        className: "title",
        begin: new RegExp("(?<=\\b(?:let|and)(?:%[a-z]+|[*+])?\\s+)[a-z_][\\w']*"),
      });
    } catch (e) { /* lookbehind unsupported: skip function-name highlighting */ }
    hljs.registerLanguage("ocaml", function () { return oc; });
  }
  if (window.hljs) {
    if (document.readyState === "loading")
      document.addEventListener("DOMContentLoaded", function () { hljs.highlightAll(); });
    else hljs.highlightAll();
  }
})();
|hl}

(* the per-page template (chrome around the odoc content); {{menu}}, {{leftnav}},
   {{base}}, {{title}}, {{preamble}}, {{content}} are filled by Assemble. *)
let template ?(body_extra = "") ?(extra_script = "") (c : Config.t) =
  (* the highlight starter is always shipped under the same name (the default,
     or the project's (highlight …) override), so the template is project-agnostic *)
  let hl = "  <script src=\"{{base}}/wodoc-highlight.js\"></script>\n" in
  Printf.sprintf
    {|<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>{{title}} — %s</title>
  <link rel="stylesheet" href="/css/style.css"/>
  <link rel="stylesheet" href="/css/ocsigen-odoc.css"/>
  <script src="{{base}}/highlight.pack.js"></script>
%s</head>
<body class="wodoc-page wodoc-doc%s">
  {{menu}}

  <div class="project-page">
    <div class="twocols">
      <nav class="leftcol">
        {{leftnav}}
      </nav>
      <article class="rightcol">
        {{preamble}}
        {{content}}
      </article>
    </div>
  </div>

  <script>
%s    var wodocPub = "%s";
    // Switch version: keep the current page, swapping only the version segment.
    function wodocVersion(v) {
      if (!v) return;
      var re = new RegExp('^(' + wodocPub + '/)[^/]+');
      var p = location.pathname;
      location.href =
        re.test(p) ? p.replace(re, '$1' + v) : wodocPub + '/' + v + '/index.html';
    }
    // Build the version <select> from the project's versions.json (the single
    // source of truth, refreshed on every build/release), so even older frozen
    // pages list the current set. Falls back to the baked <option>s on failure.
    (function () {
      var seg = (location.pathname.match(
        new RegExp('^' + wodocPub + '/([^/]+)')) || [])[1];
      function select(sel) {
        var i;
        for (i = 0; i < sel.options.length; i++)
          if (sel.options[i].value === seg) { sel.selectedIndex = i; return; }
        if (seg) {
          var o = document.createElement('option');
          o.value = seg; o.textContent = seg; o.selected = true;
          sel.insertBefore(o, sel.firstChild);
        }
      }
      fetch(wodocPub + '/versions.json')
        .then(function (r) { if (!r.ok) throw 0; return r.json(); })
        .then(function (m) {
          var list = m.list || [], latest = m.latest;
          document.querySelectorAll('.wodoc-version').forEach(function (sel) {
            sel.innerHTML = '';
            list.forEach(function (v) {
              var o = document.createElement('option');
              if (v === latest) { o.value = 'latest'; o.textContent = v + ' (latest)'; }
              else { o.value = v; o.textContent = v; }
              sel.appendChild(o);
            });
            select(sel);
          });
        })
        .catch(function () {
          document.querySelectorAll('.wodoc-version').forEach(select);
        });
    })();
  </script>
</body>
</html>
|}
    (esc c.title) hl body_extra extra_script c.pub

(* the version <select> block (shared by the normal and per-side left columns).
   The entry that the [latest] symlink targets is rendered with value "latest"
   (so it keeps the canonical /<project>/latest/ URL) and labelled "<v> (latest)".
   This is only the static fallback baked into the page: the script rebuilds the
   list from versions.json at load time so it stays fresh after future releases. *)
let docversion ~latest names =
  let b = Buffer.create 256 in
  let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
  add "<div class=\"docversion\">";
  add "  <label>Version:";
  add
    "    <select class=\"wodoc-version\" onchange=\"wodocVersion(this.value)\">";
  List.iter
    (fun v ->
       let value, label =
         if Some v = latest then "latest", v ^ " (latest)" else v, v
       in
       add
         (Printf.sprintf "      <option value=\"%s\">%s</option>" value
            (esc label)))
    names;
  add "    </select>";
  add "  </label>";
  add "</div>";
  Buffer.contents b

let page_toc =
  "<div class=\"page-toc\">\n  <h3>On this page</h3>\n  {{toc}}\n</div>\n"

(* an entry path is emitted verbatim when absolute ([/…]) or a URL, else made
   relative to the version root with the per-page [{{base}}] hole. *)
let nav_href path =
  if (String.length path > 0 && path.[0] = '/') || is_url path
  then path
  else "{{base}}/" ^ path

(* a single config-driven nav entry as an <li> at indent level [ml]. The
   data-wodoc-page key is the entry's own (local) path, so it is UNIQUE per entry:
   the page picks the single longest-prefix match (see [current_of_page]) rather
   than every entry that shares a hand-written id. Cross-project / absolute links
   get no key (they are never "current"). *)
let nav_link ml (e : Config.entry) =
  let dwp =
    if (String.length e.path > 0 && e.path.[0] = '/') || is_url e.path
    then ""
    else Printf.sprintf " data-wodoc-page=\"%s\"" e.path
  in
  Printf.sprintf "<li class=\"ml%d\"%s><a href=\"%s\">%s</a></li>\n" ml dwp
    (nav_href e.path) (esc e.label)

(* render a section body into [b] at indent level [ml]: consecutive [Link]s share
   one [<ul class="api-section">]; a [Group] closes it, emits an [<h4>] sub-heading
   and recurses one level deeper. [ml] feeds the CSS [.mlN] padding (3 = manual
   top level, deeper groups 4, 5, …; 2 = an api section's flush level). *)
let rec render_items b ml items =
  let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
  let ul = ref false in
  let close () =
    if !ul
    then (
      add "</ul>";
      ul := false)
  in
  List.iter
    (function
      | Config.Link e ->
          if not !ul
          then (
            add "<ul class=\"api-section\">";
            ul := true);
          Buffer.add_string b (nav_link ml e)
      | Config.Group (h, children) ->
          close ();
          add (Printf.sprintf "<h4 class=\"ml%d\">%s</h4>" ml (esc h));
          render_items b (ml + 1) children)
    items;
  close ()

(* the manual left-nav block from the config [(section …)] stanzas (the
   non-[api] sections of [(nav …)]) — a [<nav class="api-nav manual-nav">]. Empty
   when the project declares no manual sections. Shared by the normal left column
   and the client/server one (which used to take this from a wiki menu.wiki). *)
let manual_nav (c : Config.t) =
  let manual = List.filter (fun (s : Config.section) -> not s.api) c.nav in
  if manual = []
  then ""
  else begin
    let b = Buffer.create 512 in
    let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
    add "<nav class=\"api-nav manual-nav\">";
    List.iter
      (fun (s : Config.section) ->
         add (Printf.sprintf "<h3>%s</h3>" (esc s.heading));
         render_items b 3 s.items)
      manual;
    add "</nav>";
    Buffer.contents b
  end

(* the left column: version selector + on-this-page + the config-driven nav.
   {{base}} and {{toc}} stay as holes, filled per page by Assemble. *)
let leftnav ~latest (c : Config.t) names =
  let b = Buffer.create 1024 in
  let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
  Buffer.add_string b (docversion ~latest names);
  Buffer.add_string b page_toc;
  Buffer.add_string b (manual_nav c);
  let apis = List.filter (fun (s : Config.section) -> s.api) c.nav in
  List.iter
    (fun (s : Config.section) ->
       add "<nav class=\"api-nav\">";
       add (Printf.sprintf "<h3>%s</h3>" (esc s.heading));
       render_items b 2 s.items;
       add "</nav>")
    apis;
  Buffer.contents b

(* the version [latest] points at (its symlink target's basename), e.g. "2.3";
   None when there is no [latest] symlink (no release yet) or it is unreadable. *)
let latest_target ~root =
  try Some (Filename.basename (Unix.readlink (Filename.concat root "latest")))
  with _ -> None

(* numeric-aware comparison of version strings, component by component on '.'
   ("12.0.1" > "2.0"); non-numeric components fall back to string compare. *)
let compare_version a b =
  let rec cmp = function
    | x :: xs, y :: ys ->
        let c =
          match int_of_string_opt x, int_of_string_opt y with
          | Some i, Some j -> compare i j
          | _ -> compare x y
        in
        if c <> 0 then c else cmp (xs, ys)
    | [], [] -> 0
    | [], _ -> -1
    | _, [] -> 1
  in
  cmp (String.split_on_char '.' a, String.split_on_char '.' b)

(* ordered menu entries for [root] (the project dir holding the version dirs):
   "dev" first, then the real version dirs newest-first. A dir counts as a
   version only if it is itself a wodoc build (it carries wodoc-highlight.js):
   this skips the [latest] symlink and any source/asset dirs sitting alongside.
   [extra] forces names in even if their dir is not built yet (the label being
   built, whose tree may still be incomplete when this is first computed). *)
let version_names ~root ?(extra = []) () =
  let dirs =
    if Sys.file_exists root
    then
      Array.to_list (Sys.readdir root)
      |> List.filter (fun d ->
        d <> "latest"
        && Sys.is_directory (Filename.concat root d)
        && Sys.file_exists
             (Filename.concat (Filename.concat root d) "wodoc-highlight.js"))
    else []
  in
  let all = List.sort_uniq compare (extra @ dirs) in
  let devs, vers = List.partition (fun d -> d = "dev") all in
  devs @ List.sort (fun a b -> compare_version b a) vers

(* the menu names next to [out] (its siblings), plus the [label] being built *)
let versions ~out ~label =
  version_names ~root:(Filename.dirname out) ~extra:[label] ()

(* versions.json at the project root: the single source of truth the page script
   reads to (re)build the version <select>. Regenerated on every build and every
   release, so a release only has to rewrite this one file (no page rewriting). *)
let write_manifest ~root =
  let names = version_names ~root () in
  let latest =
    match latest_target ~root with Some v -> "\"" ^ v ^ "\"" | None -> "null"
  in
  let list =
    "[" ^ String.concat "," (List.map (fun s -> "\"" ^ s ^ "\"") names) ^ "]"
  in
  write_file
    (Filename.concat root "versions.json")
    (Printf.sprintf "{\"latest\":%s,\"list\":%s}\n" latest list)

(* Fetch the root-absolute assets the built pages reference (/css/…, /img/…, …)
   from the menu URL's site, into the parent of [out], so the result is viewable
   with a static server rooted there (the pages use absolute /css//img/ paths
   that are served by the real site but 404 on a bare local build). *)
let asset_re =
  Str.regexp
    "\\(href\\|src\\)=\"\\(/[^\"]+\\.\\(css\\|js\\|svg\\|png\\|jpe?g\\|gif\\|ico\\|woff2?\\|ttf\\)\\)\""

let local_assets ~menu ~out =
  match if is_url menu then origin_of menu else None with
  | None ->
      prerr_endline
        "wodoc build --local: --menu must be an http(s) URL to fetch assets; skipped"
  | Some origin ->
      let root = Filename.dirname out in
      let paths = Hashtbl.create 64 in
      let rec scan dir =
        Array.iter
          (fun e ->
             let p = Filename.concat dir e in
             if Sys.is_directory p
             then scan p
             else if Filename.check_suffix p ".html"
             then
               let s = read_file p in
               let i = ref 0 in
               try
                 while true do
                   ignore (Str.search_forward asset_re s !i);
                   Hashtbl.replace paths (Str.matched_group 2 s) ();
                   i := Str.match_end ()
                 done
               with Not_found -> ())
          (Sys.readdir dir)
      in
      scan out;
      Hashtbl.iter
        (fun path () ->
           let dst = root ^ path in
           mkdir_p (Filename.dirname dst);
           ignore
             (Sys.command
                (Printf.sprintf "curl -fsSL %s -o %s 2>/dev/null"
                   (Filename.quote (origin ^ path))
                   (Filename.quote dst))))
        paths;
      (* the pages use absolute /css//img/ paths, so the server must be rooted at
         [root] (the parent of <out>), not at <out> itself — spell it out. *)
      Printf.eprintf
        "wodoc build --local: fetched %d shared assets into %s\n\  preview:  (cd %s && python3 -m http.server)  then open  http://localhost:8000/%s/\n"
        (Hashtbl.length paths) root (Filename.quote root)
        (Filename.basename out)

(* ---- client/server projects (eliom, ocsigen-toolkit, ocsigen-start) ----
   The API is two (or three) libraries of the same package sharing module names
   ([<pkg>.server]/[<pkg>.client]/[<pkg>.ppx]); built with odoc_driver --remap.
   Each side gets its own API nav (from a curated index), a body colour class and
   a switch button; the manual nav is shared. *)

(* the client/server switch buttons (one per side), shown above the api nav *)
let cs_switch (sides : Config.cs_side list) =
  let b = Buffer.create 256 in
  let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
  add "<div class=\"cs-switch\">";
  List.iter
    (fun (s : Config.cs_side) ->
       add
         (Printf.sprintf
            "  <button type=\"button\" class=\"cs-%s\" onclick=\"wodocSwitch('%s')\">%s</button>"
            s.side s.side (esc s.heading)))
    sides;
  add "</div>";
  Buffer.contents b

(* the wodocSwitch() helper, injected into the page script: jump to the same
   module's page on another side by swapping the [<pkg>.<side>] path segment;
   fall back to that side's wrapper-module index. *)
let cs_switch_script (c : Config.t) (sides : Config.cs_side list) =
  let alt =
    String.concat "|" (List.map (fun (s : Config.cs_side) -> s.side) sides)
  in
  let wmap =
    String.concat ", "
      (List.map
         (fun (s : Config.cs_side) ->
            Printf.sprintf "%s: '%s'" s.side
              (if s.wrapper = "" then "" else s.wrapper ^ "/"))
         sides)
  in
  Printf.sprintf
    "    // Toggle between the %s API of the same module.\n\    function wodocSwitch(side) {\n\      var w = { %s };\n\      var p = location.pathname;\n\      var np = p.replace(/\\/%s\\.(%s)\\//, '/%s.' + side + '/');\n\      location.href = np !== p ? np\n\        : '{{base}}/%s.' + side + '/' + (w[side] || '') + 'index.html';\n\    }\n"
    (String.concat " / " (List.map (fun (s : Config.cs_side) -> s.side) sides))
    wmap c.project alt c.project c.project

(* the per-side left column: version selector + switch + on-this-page + the
   shared manual nav + this side's API nav ({{base}}/{{toc}} filled per page). *)
let cs_leftnav ~latest ~versions ~switch ~manual_nav ~api_nav =
  String.concat ""
    [docversion ~latest versions; switch; page_toc; manual_nav; "\n"; api_nav]

(* a page's top directory ([<pkg>.<side>…/…]); None for a root manual page *)
let topdir rel =
  match String.index_opt rel '/' with
  | Some i -> Some (String.sub rel 0 i)
  | None -> None

(* the side a top dir belongs to: the side whose lib it is, or a sub-library of
   ([eliom.server] but also [eliom.server.monitor] → server). *)
let side_for (sides : Config.cs_side list) td =
  List.find_opt
    (fun (s : Config.cs_side) ->
       td = s.lib || String.starts_with ~prefix:(s.lib ^ ".") td)
    sides

(* the side a page belongs to (by its top dir), "" for the manual / other libs *)
let side_of sides rel =
  match topdir rel with
  | None -> ""
  | Some td -> ( match side_for sides td with Some s -> s.side | None -> "")

let drop_prefix p str =
  if String.starts_with ~prefix:p str
  then String.sub str (String.length p) (String.length str - String.length p)
  else str

(* the nav id to highlight: an API page's module path (under <topdir>/<wrapper>/,
   dotted), or a root manual page's own name (matching the config nav / Nav.api). *)
let cs_current sides rel =
  match topdir rel with
  | None ->
      rel (* root manual page: matches manual_nav's data-wodoc-page = path *)
  | Some td ->
      let wrapper =
        match side_for sides td with Some s -> s.wrapper | None -> ""
      in
      let rest = drop_prefix (td ^ "/") rel in
      let rest =
        if wrapper = "" then rest else drop_prefix (wrapper ^ "/") rest
      in
      let rest =
        if Filename.check_suffix rest "/index.html"
        then Filename.chop_suffix rest "/index.html"
        else rest
      in
      String.map (fun c -> if c = '/' then '.' else c) rest

(* the local (relative) entry paths declared in the config nav — the candidates
   for the "current" highlight (cross-project / absolute entries are excluded). *)
let nav_entry_paths (c : Config.t) =
  let local p = not ((String.length p > 0 && p.[0] = '/') || is_url p) in
  let rec items acc = function
    | [] -> acc
    | Config.Link e :: t ->
        items (if local e.path then e.path :: acc else acc) t
    | Config.Group (_, sub) :: t -> items (items acc sub) t
  in
  List.fold_left (fun acc (s : Config.section) -> items acc s.items) [] c.nav

(* drop a trailing "index.html" so a directory page compares as its directory *)
let strip_index p =
  if Filename.check_suffix p "index.html"
  then Filename.chop_suffix p "index.html"
  else p

(* the data-wodoc-page key to highlight for the page deployed at [orel]: the nav
   entry whose path is the longest prefix of — or an exact match for — the page.
   Computed statically so exactly ONE left-nav entry is marked. "" if none. *)
let current_of_page orel paths =
  let pp = strip_index orel in
  fst
    (List.fold_left
       (fun (best, blen) ep ->
          let e = strip_index ep in
          let m =
            pp = e
            || String.length e > 0
               && e.[String.length e - 1] = '/'
               && String.starts_with ~prefix:e pp
          in
          if m && String.length e > blen
          then ep, String.length e
          else best, blen)
       ("", -1) paths)

(* [run cfg ~src ~out ~label ~menu ~set_latest]: assemble [src] (an odoc _html
   tree) into [out]/<label-relative> using the project [cfg]. *)
let run
      (c : Config.t)
      ~src
      ~md_src
      ~out
      ~label
      ~menu
      ~assets_dir
      ~local
      ~set_latest
  =
  mkdir_p out;
  let menu_html = read_menu menu in
  let subproject =
    Printf.sprintf "<p class=\"logo-subproject\">%s</p>" (esc c.title)
  in
  let vs = versions ~out ~label in
  let latest = latest_target ~root:(Filename.dirname out) in
  (* manual-root: strip the leading <package>/ from output paths, nav links and
     the landing so a single-package project deploys at the version ROOT (like
     eliom's odoc-driver layout). The package's internal links are relative, so
     stripping the same prefix from every page keeps them valid. *)
  let strip_pfx =
    if c.manual_root
    then Some ((match c.packages with p :: _ -> p | [] -> c.project) ^ "/")
    else None
  in
  let strip rel =
    match strip_pfx with
    | Some p when String.starts_with ~prefix:p rel ->
        String.sub rel (String.length p) (String.length rel - String.length p)
    | _ -> rel
  in
  let rec strip_items items =
    List.map
      (function
        | Config.Link e -> Config.Link {e with path = strip e.path}
        | Config.Group (h, children) -> Config.Group (h, strip_items children))
      items
  in
  let c =
    match strip_pfx with
    | None -> c
    | Some _ ->
        { c with
          landing = strip c.landing
        ; nav =
            List.map
              (fun (s : Config.section) -> {s with items = strip_items s.items})
              c.nav }
  in
  (* blog: discover the dated posts (newest first) and splice a generated nav
     section into the config nav, so every page's left column lists them and the
     per-page "current" highlight can match a post page. *)
  let blog_posts = match c.blog with Some b -> Blog.posts b | None -> [] in
  let c =
    match c.blog with
    | Some b when blog_posts <> [] ->
        {c with nav = c.nav @ [Blog.nav_section b blog_posts]}
    | _ -> c
  in
  (* the "latest posts" fragment that the {%wodoc:blog-latest%} marker expands to,
     per page (the link base differs by page depth); a no-op without a blog. *)
  let expand_blog ~base page =
    match c.blog with
    | Some b ->
        Blog.expand ~fragment:(Blog.latest_fragment ~base b blog_posts) page
    | None -> page
  in
  (* direct-mld build (manual-only/archived): the pages ARE the manual and the
     landing index.html is a real page, so keep it and write no redirect. *)
  let mld_mode = c.mld_dir <> None in
  (* the pages to assemble: the explicit (packages …) subtrees, or — by default —
     every .html odoc produced (recursively), skipping its support assets and the
     top-level package-list index (replaced by the redirect below). Default covers
     both API under package dirs AND manual pages that odoc emits at the root. *)
  let rels =
    if c.packages <> []
    then List.concat_map (html_files src) c.packages
    else
      let acc = ref [] in
      let rec walk rel =
        let abs = if rel = "" then src else Filename.concat src rel in
        if Sys.is_directory abs
        then
          Array.iter
            (fun e ->
               if not (rel = "" && e = "odoc.support")
               then walk (if rel = "" then e else Filename.concat rel e))
            (Sys.readdir abs)
        else if
          Filename.check_suffix rel ".html" && (mld_mode || rel <> "index.html")
        then acc := rel :: !acc
      in
      walk ""; List.sort compare !acc
  in
  (* the per-page assembler: one shared nav (normal projects), or a per-side
     template + nav for client/server projects (eliom/toolkit/start). *)
  let assemble_page =
    match c.client_server with
    | [] ->
        let tmpl = replace_hole (template c) "pub" c.pub in
        (* left nav: version selector + on-this-page + the config-declared
           [(nav …)] sections. *)
        let nav = leftnav ~latest c vs in
        let nav_paths = nav_entry_paths c in
        fun rel ->
          (* output position after manual-root stripping drives base/current *)
          let orel = strip rel in
          let base = base_of orel in
          (* the single left-nav entry to highlight: the longest-prefix match for
             this page among the config nav entries (so an "Overview" and a module
             page in the same package no longer light up together) *)
          let current = current_of_page orel nav_paths in
          let page =
            Assemble.page ~flat:c.flat ~base ~menu:menu_html ~subproject
              ~menu_current:c.menu_current ~leftnav:nav ~template:tmpl ~current
              (read_file (Filename.concat src rel))
          in
          let page = expand_blog ~base page in
          if c.siblings = []
          then page
          else Resolve.html ~siblings:c.siblings ~base page
    | sides ->
        let script = cs_switch_script c sides in
        let switch = cs_switch sides in
        (* the shared manual nav comes from the config [(section …)] stanzas *)
        let manual_nav = manual_nav c in
        let default_side = match sides with s :: _ -> s.side | [] -> "" in
        let api_nav =
          List.map
            (fun (s : Config.cs_side) ->
               ( s.side
               , if Sys.file_exists s.indexdoc
                 then
                   Nav.api ~wrapper:s.wrapper ~heading:s.heading ~skip:s.skip
                     ~base:"{{base}}" ~lib:s.lib (read_file s.indexdoc)
                 else "" ))
            sides
        in
        let api_of side =
          match List.assoc_opt side api_nav with
          | Some n -> n
          | None ->
              Option.value ~default:"" (List.assoc_opt default_side api_nav)
        in
        (* template (by body side class) and left column (by api side) cached:
           there are at most a handful of distinct sides *)
        let tcache = Hashtbl.create 4 and ncache = Hashtbl.create 4 in
        let tmpl_of side =
          match Hashtbl.find_opt tcache side with
          | Some t -> t
          | None ->
              let body_extra = if side = "" then "" else " wodoc-" ^ side in
              let t =
                replace_hole
                  (template ~body_extra ~extra_script:script c)
                  "pub" c.pub
              in
              Hashtbl.add tcache side t; t
        in
        let leftnav_of side =
          match Hashtbl.find_opt ncache side with
          | Some n -> n
          | None ->
              let n =
                cs_leftnav ~latest ~versions:vs ~switch ~manual_nav
                  ~api_nav:(api_of side)
              in
              Hashtbl.add ncache side n; n
        in
        fun rel ->
          let base = base_of rel in
          let side = side_of sides rel in
          (* manual/other pages have no side colour but show the default api nav *)
          let nav_side = if side = "" then default_side else side in
          let page =
            Assemble.page ~base ~menu:menu_html ~subproject
              ~menu_current:c.menu_current ~leftnav:(leftnav_of nav_side)
              ~template:(tmpl_of side) ~current:(cs_current sides rel)
              (read_file (Filename.concat src rel))
          in
          let page = expand_blog ~base page in
          if c.hosted = []
          then page
          else
            Resolve.deps ~hosted:c.hosted ~relroot:(base ^ "/../..") ~side
              ~self:c.project page
  in
  List.iter
    (fun rel ->
       let dst = Filename.concat out (strip rel) in
       mkdir_p (Filename.dirname dst);
       write_file dst (assemble_page rel))
    rels;
  (* the markdown twin tree: odoc's markdown backend emits a flat-module layout
     ([<pkg>/Mod-Sub.md]) parallel to the HTML one, with self-consistent relative
     .md xrefs. Copy it verbatim next to the HTML, applying the same manual-root
     [strip] so the .md siblings land beside their .html pages and stay linkable.
     This is what AIs/LLMs consume; the per-page <link rel="alternate"> and the
     llms.txt index (below) point into it. *)
  (match md_src with
  | Some root when Sys.file_exists root ->
      let rec walk rel =
        let abs = if rel = "" then root else Filename.concat root rel in
        if Sys.is_directory abs
        then
          Array.iter
            (fun e -> walk (if rel = "" then e else Filename.concat rel e))
            (Sys.readdir abs)
        else if Filename.check_suffix rel ".md"
        then (
          let dst = Filename.concat out (strip rel) in
          mkdir_p (Filename.dirname dst);
          write_file dst (read_file abs))
      in
      walk ""
  | _ -> ());
  (* blog posts: each post .mld is compiled straight with odoc (preprocess ->
     compile -> link -> html-generate, the direct-mld pipeline), then assembled
     with the same site chrome and the (blog-augmented) left nav, and written to
     <out>/<blog.out>/<slug>.html. Assembled as a normal (non-side) page, so a
     blog works for any project type. *)
  (match c.blog with
  | Some _ when blog_posts <> [] ->
      let tmpl = replace_hole (template c) "pub" c.pub in
      let nav = leftnav ~latest c vs in
      let nav_paths = nav_entry_paths c in
      let work = "_wodoc-blog" in
      let odoc = Filename.concat work "odoc"
      and html = Filename.concat work "html" in
      let rec find_html dir =
        Array.to_list (Sys.readdir dir)
        |> List.concat_map (fun e ->
          let p = Filename.concat dir e in
          if Sys.is_directory p
          then find_html p
          else if Filename.check_suffix p ".html"
          then [p]
          else [])
      in
      List.iter
        (fun (p : Blog.post) ->
           ignore
             (Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote work)));
           mkdir_p odoc;
           mkdir_p html;
           let pp = Filename.concat odoc ("pp-" ^ p.slug ^ ".mld") in
           write_file pp (Preprocess.string (read_file p.src));
           let odocf = Filename.concat odoc ("page-" ^ p.slug ^ ".odoc") in
           let odoclf = Filename.concat odoc ("page-" ^ p.slug ^ ".odocl") in
           let cmd =
             Printf.sprintf
               "odoc compile %s -I %s -o %s && odoc link %s -I %s -o %s && odoc html-generate %s -o %s"
               (Filename.quote pp) (Filename.quote odoc) (Filename.quote odocf)
               (Filename.quote odocf) (Filename.quote odoc)
               (Filename.quote odoclf) (Filename.quote odoclf)
               (Filename.quote html)
           in
           if Sys.command cmd <> 0
           then prerr_endline ("wodoc build: odoc failed on blog post " ^ p.src)
           else
             match find_html html with
             | [] ->
                 prerr_endline ("wodoc build: no HTML for blog post " ^ p.src)
             | hf :: _ ->
                 let orel = p.path in
                 let base = base_of orel in
                 let current = current_of_page orel nav_paths in
                 let page =
                   Assemble.page ~flat:c.flat ~base ~menu:menu_html ~subproject
                     ~menu_current:c.menu_current ~leftnav:nav ~template:tmpl
                     ~current (read_file hf)
                 in
                 let page = expand_blog ~base page in
                 let page =
                   if c.siblings = []
                   then page
                   else Resolve.html ~siblings:c.siblings ~base page
                 in
                 let dst = Filename.concat out orel in
                 mkdir_p (Filename.dirname dst);
                 write_file dst page)
        blog_posts;
      ignore (Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote work)))
  | _ -> ());
  (* version root index.html: redirect to the landing page — UNLESS the landing
     IS this version-root index.html, i.e. a real manual page already written here
     (direct-mld builds, or manual-root single-package projects whose index.mld
     lands at the root). Writing the redirect would then clobber the real page and
     add a needless second hop. Body kept empty so the redirect flashes blank
     (instead of briefly showing "Redirecting…" text). *)
  let wrote_root_index =
    mld_mode
    || c.landing = "index.html"
       && List.exists (fun rel -> strip rel = "index.html") rels
  in
  if not wrote_root_index
  then
    write_file
      (Filename.concat out "index.html")
      (Printf.sprintf
         "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"/>\n<meta http-equiv=\"refresh\" content=\"0; url=%s\"/>\n<link rel=\"canonical\" href=\"%s\"/>\n<title>%s documentation</title></head>\n<body></body>\n</html>\n"
         c.landing c.landing (esc c.title));
  (* verbatim copies (frozen API snapshot, manual images, …) *)
  List.iter
    (fun (csrc, dest) ->
       if Sys.file_exists csrc
       then (
         let d = Filename.concat out dest in
         mkdir_p (Filename.dirname d);
         ignore
           (Sys.command
              (Printf.sprintf "cp -a %s %s" (Filename.quote csrc)
                 (Filename.quote d)))))
    c.static_copy;
  (* assets: odoc's bundled highlighter + the project's highlight starter *)
  let sf = Filename.temp_file "wodoc-sf" "" in
  Sys.remove sf;
  (if
     Sys.command
       (Printf.sprintf "odoc support-files -o %s >/dev/null 2>&1"
          (Filename.quote sf))
     = 0
   then
     let pack = Filename.concat sf "highlight.pack.js" in
     if Sys.file_exists pack
     then write_file (Filename.concat out "highlight.pack.js") (read_file pack));
  (* the highlight starter, always shipped as wodoc-highlight.js: the project's
     (highlight <file>) override if any, else wodoc's built-in default *)
  let hl_js =
    match c.highlight with
    | Some h when Sys.file_exists (Filename.concat assets_dir h) ->
        read_file (Filename.concat assets_dir h)
    | _ -> default_highlight
  in
  write_file (Filename.concat out "wodoc-highlight.js") hl_js;
  (* manual assets (examples, images): `dune build @doc-manual` always writes
     them to _build/default/manual/files, regardless of whether the API was
     built by `dune build @doc` (src = _build/default/_doc/_html) or by
     odoc_driver (src = _wodoc-html/<pkg>), so use that canonical path. *)
  (match c.manual_files with
  | Some pkg ->
      let files = "_build/default/manual/files" in
      if Sys.file_exists files
      then begin
        let dst = Filename.concat out pkg in
        mkdir_p dst;
        ignore
          (Sys.command
             (Printf.sprintf "cp -RL %s %s 2>/dev/null || cp -R %s %s"
                (Filename.quote files) (Filename.quote dst)
                (Filename.quote files) (Filename.quote dst)))
      end
  | None -> ());
  (* direct-mld mode: pages live at the version root and reference their assets
     as [files/...] (relative to that root), so copy [<mld-dir>/files] verbatim
     to [<out>/files] when present *)
  (match c.mld_dir with
  | Some d when Sys.file_exists (Filename.concat d "files") ->
      let files = Filename.concat d "files" in
      let dst = Filename.concat out "files" in
      ignore
        (Sys.command
           (Printf.sprintf
              "rm -rf %s && { cp -RL %s %s 2>/dev/null || cp -R %s %s; }"
              (Filename.quote dst) (Filename.quote files) (Filename.quote dst)
              (Filename.quote files) (Filename.quote dst)))
  | _ -> ());
  if set_latest
  then begin
    ignore
      (Sys.command
         (Printf.sprintf "ln -sfn %s %s" (Filename.quote label)
            (Filename.quote (Filename.concat (Filename.dirname out) "latest"))));
    (* project-root redirect: <project>/index.html -> latest/index.html. Stable
       target (always the `latest` symlink), so the project is reachable from
       ocsigen.org/wodoc/<project>/ regardless of which version was just built. *)
    write_file
      (Filename.concat (Filename.dirname out) "index.html")
      (Printf.sprintf
         "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"/>\n<meta http-equiv=\"refresh\" content=\"0; url=latest/index.html\"/>\n<link rel=\"canonical\" href=\"latest/index.html\"/>\n<title>%s documentation</title></head>\n<body></body>\n</html>\n"
         (esc c.title))
  end;
  (* refresh the version manifest the page script reads (now that this build's
     dir and any new [latest] symlink are in place) *)
  write_manifest ~root:(Filename.dirname out);
  if local then local_assets ~menu ~out

(* [release ~site ~from ~version]: the stable-version release procedure. The CI
   only ever (re)builds [<site>/dev]; a stable version is a frozen snapshot of it.
   Copy [<site>/<from>] (default "dev") to [<site>/<version>], repoint the
   [latest] symlink at it, and ensure the project-root redirect exists. Older
   version directories are left untouched. *)
let release ~site ~from ~version =
  let src = Filename.concat site from in
  if not (Sys.file_exists src)
  then (
    Printf.eprintf "wodoc release: source %s does not exist\n" src;
    exit 1);
  let dst = Filename.concat site version in
  ignore (Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dst)));
  if
    Sys.command
      (Printf.sprintf "cp -a %s %s" (Filename.quote src) (Filename.quote dst))
    <> 0
  then (
    Printf.eprintf "wodoc release: copy %s -> %s failed\n" src dst;
    exit 1);
  ignore
    (Sys.command
       (Printf.sprintf "ln -sfn %s %s" (Filename.quote version)
          (Filename.quote (Filename.concat site "latest"))));
  (* the project-root redirect points at the stable [latest] symlink, so it does
     not change between releases; write it once if missing. *)
  let idx = Filename.concat site "index.html" in
  if not (Sys.file_exists idx)
  then
    write_file idx
      "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"/>\n<meta http-equiv=\"refresh\" content=\"0; url=latest/index.html\"/>\n<link rel=\"canonical\" href=\"latest/index.html\"/>\n<title>Documentation</title></head>\n<body></body>\n</html>\n";
  (* GitHub Pages: serve the static odoc/wodoc site as-is. Without this, Pages runs
     Jekyll, which is slow on large API sites and skips underscore-prefixed odoc
     directories. Written once at the site root if missing. *)
  let nj = Filename.concat site ".nojekyll" in
  if not (Sys.file_exists nj) then write_file nj "";
  (* refresh the version manifest so the new version + [latest] target show up in
     every page's selector — this is the only file a release needs to rewrite. *)
  write_manifest ~root:site;
  Printf.eprintf "wodoc release: froze %s -> %s, latest -> %s\n" from version
    version
