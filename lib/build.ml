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
%s    function wodocVersion(v) {
      if (!v) return;
      var re = new RegExp('^(%s/)[^/]+');
      var p = location.pathname;
      location.href = re.test(p) ? p.replace(re, '$1' + v) : '%s/' + v + '/index.html';
    }
    (function () {
      var m = location.pathname.match(new RegExp('^%s/([^/]+)'));
      if (!m) return;
      document.querySelectorAll('.wodoc-version').forEach(function (sel) {
        var ok = false, i;
        for (i = 0; i < sel.options.length; i++)
          if (sel.options[i].value === m[1]) { sel.selectedIndex = i; ok = true; break; }
        if (!ok) {
          var o = document.createElement('option');
          o.value = m[1]; o.textContent = m[1]; o.selected = true;
          sel.insertBefore(o, sel.firstChild);
        }
      });
    })();
  </script>
</body>
</html>
|}
    (esc c.title) hl body_extra extra_script c.pub c.pub c.pub

(* the version <select> block (shared by the normal and per-side left columns) *)
let docversion versions =
  let b = Buffer.create 256 in
  let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
  add "<div class=\"docversion\">";
  add "  <label>Version:";
  add
    "    <select class=\"wodoc-version\" onchange=\"wodocVersion(this.value)\">";
  List.iter
    (fun v -> add (Printf.sprintf "      <option value=\"%s\">%s</option>" v v))
    versions;
  add "    </select>";
  add "  </label>";
  add "</div>";
  Buffer.contents b

let page_toc =
  "<div class=\"page-toc\">\n  <h3>On this page</h3>\n  {{toc}}\n</div>\n"

(* the left column: version selector + on-this-page + the config-driven nav.
   {{base}} and {{toc}} stay as holes, filled per page by Assemble. *)
let leftnav (c : Config.t) versions =
  let b = Buffer.create 1024 in
  let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
  Buffer.add_string b (docversion versions);
  Buffer.add_string b page_toc;
  let entry cls (e : Config.entry) =
    let dwp =
      if e.current = ""
      then ""
      else Printf.sprintf " data-wodoc-page=\"%s\"" e.current
    in
    add
      (Printf.sprintf "<li class=\"%s\"%s><a href=\"{{base}}/%s\">%s</a></li>"
         cls dwp e.path (esc e.label))
  in
  let manual = List.filter (fun (s : Config.section) -> not s.api) c.nav in
  let apis = List.filter (fun (s : Config.section) -> s.api) c.nav in
  if manual <> []
  then begin
    add "<nav class=\"api-nav manual-nav\">";
    List.iter
      (fun (s : Config.section) ->
         add (Printf.sprintf "<h3>%s</h3>" (esc s.heading));
         add "<ul class=\"api-section\">";
         List.iter (entry "ml3") s.entries;
         add "</ul>")
      manual;
    add "</nav>"
  end;
  List.iter
    (fun (s : Config.section) ->
       add "<nav class=\"api-nav\">";
       add (Printf.sprintf "<h3>%s</h3>" (esc s.heading));
       add "<ul class=\"api-section\">";
       List.iter (entry "ml2") s.entries;
       add "</ul>";
       add "</nav>")
    apis;
  Buffer.contents b

(* version directories already present next to [out] (its siblings), plus the
   one being built, "latest" first — for the version <select>. A sibling counts
   as a version only if it is itself a wodoc build (it carries wodoc-highlight.js):
   this skips source/asset dirs that may sit alongside the versions (e.g. a
   project whose mld/ or api-snapshot/ live next to its built versions). *)
let versions ~out ~label =
  let parent = Filename.dirname out in
  let dirs =
    if Sys.file_exists parent
    then
      Array.to_list (Sys.readdir parent)
      |> List.filter (fun d ->
        d <> "latest"
        && Sys.is_directory (Filename.concat parent d)
        && Sys.file_exists
             (Filename.concat (Filename.concat parent d) "wodoc-highlight.js"))
    else []
  in
  let all = "latest" :: List.sort compare (label :: dirs) in
  List.fold_left (fun acc v -> if List.mem v acc then acc else acc @ [v]) [] all

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
let cs_leftnav ~versions ~switch ~manual_nav ~api_nav =
  String.concat ""
    [docversion versions; switch; page_toc; manual_nav; "\n"; api_nav]

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
   dotted), or a root manual page's own name (matching Nav.manual / Nav.api). *)
let cs_current sides rel =
  match topdir rel with
  | None -> Filename.remove_extension rel
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

(* [run cfg ~src ~out ~label ~menu ~set_latest]: assemble [src] (an odoc _html
   tree) into [out]/<label-relative> using the project [cfg]. *)
let run (c : Config.t) ~src ~out ~label ~menu ~assets_dir ~local ~set_latest =
  mkdir_p out;
  let menu_html = read_menu menu in
  let subproject =
    Printf.sprintf "<p class=\"logo-subproject\">%s</p>" (esc c.title)
  in
  let vs = versions ~out ~label in
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
        (* left nav: a single page's in-page anchors, a wiki manual menu, or — by
           default — the config-declared sections. *)
        let nav =
          match c.anchor_menu, c.manual_menu with
          | Some f, _ when Sys.file_exists f ->
              docversion vs ^ page_toc
              ^ Nav.anchors ~base:"{{base}}" (read_file f)
          | _, Some f when Sys.file_exists f ->
              docversion vs ^ page_toc
              ^ Nav.manual ~base:"{{base}}" (read_file f)
          | _ -> leftnav c vs
        in
        fun rel ->
          let base = base_of rel in
          (* current nav id: an API page's top package dir, or a root manual
             page's own name (so the matching left-nav entry is highlighted) *)
          let current =
            match String.index_opt rel '/' with
            | Some i -> String.sub rel 0 i
            | None -> Filename.remove_extension rel
          in
          let page =
            Assemble.page ~flat:c.flat ~base ~menu:menu_html ~subproject
              ~menu_current:c.menu_current ~leftnav:nav ~template:tmpl ~current
              (read_file (Filename.concat src rel))
          in
          if c.siblings = []
          then page
          else Resolve.html ~siblings:c.siblings ~base page
    | sides ->
        let script = cs_switch_script c sides in
        let switch = cs_switch sides in
        let manual_nav =
          match c.manual_menu with
          | Some f when Sys.file_exists f ->
              Nav.manual ~base:"{{base}}" (read_file f)
          | _ -> ""
        in
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
                cs_leftnav ~versions:vs ~switch ~manual_nav
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
          if c.hosted = []
          then page
          else
            Resolve.deps ~hosted:c.hosted ~relroot:(base ^ "/../..") ~side
              ~self:c.project page
  in
  List.iter
    (fun rel ->
       let dst = Filename.concat out rel in
       mkdir_p (Filename.dirname dst);
       write_file dst (assemble_page rel))
    rels;
  (* version root index.html: redirect to the landing page — UNLESS this is a
     direct-mld build, whose index.html is a real manual page already written. *)
  if not mld_mode
  then
    write_file
      (Filename.concat out "index.html")
      (Printf.sprintf
         "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"/>\n<meta http-equiv=\"refresh\" content=\"0; url=%s\"/>\n<link rel=\"canonical\" href=\"%s\"/>\n<title>%s documentation</title></head>\n<body><p>Redirecting to the <a href=\"%s\">%s documentation</a>.</p></body>\n</html>\n"
         c.landing c.landing (esc c.title) c.landing (esc c.title));
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
  (* manual assets (examples, images): odoc puts them under <dune>/manual/files,
     a sibling of the _doc/_html tree given as [src] *)
  (match c.manual_files with
  | Some pkg ->
      let files =
        Filename.concat (Filename.dirname (Filename.dirname src)) "manual/files"
      in
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
         "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"/>\n<meta http-equiv=\"refresh\" content=\"0; url=latest/index.html\"/>\n<link rel=\"canonical\" href=\"latest/index.html\"/>\n<title>%s documentation</title></head>\n<body><p>Redirecting to the <a href=\"latest/index.html\">%s documentation</a>.</p></body>\n</html>\n"
         (esc c.title) (esc c.title))
  end;
  if local then local_assets ~menu ~out
