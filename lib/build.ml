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
  output_string oc s;
  close_out oc

let rec mkdir_p dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir)
  then (mkdir_p (Filename.dirname dir); (try Sys.mkdir dir 0o755 with Sys_error _ -> ()))

(* relative .html files under [root]/[sub], as "sub/...": odoc's page tree *)
let html_files root sub =
  let acc = ref [] in
  let rec walk rel =
    let abs = Filename.concat root rel in
    if Sys.is_directory abs
    then Array.iter (fun e -> walk (Filename.concat rel e)) (Sys.readdir abs)
    else if Filename.check_suffix rel ".html" then acc := rel :: !acc
  in
  if Sys.file_exists (Filename.concat root sub) then walk sub;
  List.sort compare !acc

(* "." / ".." / "../.." … : relative path from a page at depth [d] to the root *)
let base_of rel =
  let d = String.fold_left (fun n c -> if c = '/' then n + 1 else n) 0 rel in
  if d = 0 then "." else String.concat "/" (List.init d (fun _ -> "..")) |> fun s -> s

let replace_hole template key value =
  Str.global_replace (Str.regexp_string ("{{" ^ key ^ "}}")) value template

let esc = Resolve.html_escape

(* the per-page template (chrome around the odoc content); {{menu}}, {{leftnav}},
   {{base}}, {{title}}, {{preamble}}, {{content}} are filled by Assemble. *)
let template (c : Config.t) =
  let hl =
    match c.highlight with
    | Some h -> Printf.sprintf "  <script src=\"{{base}}/%s\"></script>\n" h
    | None -> ""
  in
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
<body class="wodoc-page wodoc-doc">
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
    function wodocVersion(v) {
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
    (esc c.title) hl c.pub c.pub c.pub

(* the left column: version selector + on-this-page + the config-driven nav.
   {{base}} and {{toc}} stay as holes, filled per page by Assemble. *)
let leftnav (c : Config.t) versions =
  let b = Buffer.create 1024 in
  let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
  add "<div class=\"docversion\">";
  add "  <label>Version:";
  add "    <select class=\"wodoc-version\" onchange=\"wodocVersion(this.value)\">";
  List.iter (fun v -> add (Printf.sprintf "      <option value=\"%s\">%s</option>" v v)) versions;
  add "    </select>";
  add "  </label>";
  add "</div>";
  add "<div class=\"page-toc\">";
  add "  <h3>On this page</h3>";
  add "  {{toc}}";
  add "</div>";
  let entry cls (e : Config.entry) =
    let dwp = if e.current = "" then "" else Printf.sprintf " data-wodoc-page=\"%s\"" e.current in
    add (Printf.sprintf "<li class=\"%s\"%s><a href=\"{{base}}/%s\">%s</a></li>" cls dwp e.path (esc e.label))
  in
  let manual = List.filter (fun (s : Config.section) -> not s.api) c.nav in
  let apis = List.filter (fun (s : Config.section) -> s.api) c.nav in
  if manual <> [] then begin
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
   one being built, "latest" first — for the version <select>. *)
let versions ~out ~label =
  let parent = Filename.dirname out in
  let dirs =
    if Sys.file_exists parent
    then
      Array.to_list (Sys.readdir parent)
      |> List.filter (fun d -> d <> "latest" && Sys.is_directory (Filename.concat parent d))
    else []
  in
  let all = "latest" :: List.sort compare (label :: dirs) in
  List.fold_left (fun acc v -> if List.mem v acc then acc else acc @ [ v ]) [] all

(* [run cfg ~src ~out ~label ~menu ~set_latest]: assemble [src] (an odoc _html
   tree) into [out]/<label-relative> using the project [cfg]. *)
let run (c : Config.t) ~src ~out ~label ~menu ~assets_dir ~set_latest =
  mkdir_p out;
  let tmpl = replace_hole (template c) "pub" c.pub in
  let menu_html = read_file menu in
  let nav = leftnav c (versions ~out ~label) in
  let subproject = Printf.sprintf "<p class=\"logo-subproject\">%s</p>" (esc c.title) in
  (* with no explicit (packages ...), assemble every top-level subtree odoc
     produced (skipping its support assets and the top package-list index) *)
  let pkgs =
    if c.packages <> []
    then c.packages
    else
      Array.to_list (Sys.readdir src)
      |> List.filter (fun e -> e <> "odoc.support" && Sys.is_directory (Filename.concat src e))
      |> List.sort compare
  in
  List.iter
    (fun pkg ->
       List.iter
         (fun rel ->
            let base = base_of rel in
            let current = match String.index_opt rel '/' with Some i -> String.sub rel 0 i | None -> "" in
            let page =
              Assemble.page ~base ~menu:menu_html ~subproject ~menu_current:c.menu_current
                ~leftnav:nav ~template:tmpl ~current (read_file (Filename.concat src rel))
            in
            let page =
              if c.siblings = [] then page
              else Resolve.html ~siblings:c.siblings ~base page
            in
            let dst = Filename.concat out rel in
            mkdir_p (Filename.dirname dst);
            write_file dst page)
         (html_files src pkg))
    pkgs;
  (* version root index.html: redirect to the landing page *)
  write_file (Filename.concat out "index.html")
    (Printf.sprintf
       "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"/>\n<meta http-equiv=\"refresh\" content=\"0; url=%s\"/>\n<link rel=\"canonical\" href=\"%s\"/>\n<title>%s documentation</title></head>\n<body><p>Redirecting to the <a href=\"%s\">%s documentation</a>.</p></body>\n</html>\n"
       c.landing c.landing (esc c.title) c.landing (esc c.title));
  (* assets: odoc's bundled highlighter + the project's highlight starter *)
  let sf = Filename.temp_file "wodoc-sf" "" in
  Sys.remove sf;
  (if Sys.command (Printf.sprintf "odoc support-files -o %s >/dev/null 2>&1" (Filename.quote sf)) = 0
   then
     let pack = Filename.concat sf "highlight.pack.js" in
     if Sys.file_exists pack then write_file (Filename.concat out "highlight.pack.js") (read_file pack));
  (match c.highlight with
   | Some h ->
       let srcf = Filename.concat assets_dir h in
       if Sys.file_exists srcf then write_file (Filename.concat out h) (read_file srcf)
   | None -> ());
  (* manual assets (examples, images): odoc puts them under <dune>/manual/files,
     a sibling of the _doc/_html tree given as [src] *)
  (match c.manual_files with
   | Some pkg ->
       let files = Filename.concat (Filename.dirname (Filename.dirname src)) "manual/files" in
       if Sys.file_exists files then begin
         let dst = Filename.concat out pkg in
         mkdir_p dst;
         ignore (Sys.command (Printf.sprintf "cp -RL %s %s 2>/dev/null || cp -R %s %s"
                                (Filename.quote files) (Filename.quote dst)
                                (Filename.quote files) (Filename.quote dst)))
       end
   | None -> ());
  if set_latest then
    ignore (Sys.command (Printf.sprintf "ln -sfn %s %s"
                           (Filename.quote label)
                           (Filename.quote (Filename.concat (Filename.dirname out) "latest"))))
