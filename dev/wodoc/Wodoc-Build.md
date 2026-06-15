
# Module `Wodoc.Build`

```ocaml
val read_file : string -> string
```
```ocaml
val write_file : string -> string -> unit
```
```ocaml
val is_url : string -> bool
```
```ocaml
val origin_of : string -> string option
```
```ocaml
val read_menu : string -> string
```
```ocaml
val mkdir_p : string -> unit
```
```ocaml
val html_files : string -> string -> string list
```
```ocaml
val base_of : string -> string
```
```ocaml
val replace_hole : string -> string -> string -> string
```
```ocaml
val esc : string -> string
```
```ocaml
val default_highlight : string
```
```ocaml
val template : ?body_extra:string -> ?extra_script:string -> Config.t -> string
```
```ocaml
val docversion : latest:string option -> string list -> string
```
```ocaml
val page_toc : string
```
```ocaml
val nav_href : string -> string
```
```ocaml
val nav_link : int -> Config.entry -> string
```
```ocaml
val render_items : Stdlib.Buffer.t -> int -> Config.item list -> unit
```
```ocaml
val manual_nav : Config.t -> string
```
```ocaml
val leftnav : latest:string option -> Config.t -> string list -> string
```
```ocaml
val latest_target : root:string -> string option
```
```ocaml
val compare_version : string -> string -> int
```
```ocaml
val version_names : root:string -> ?extra:string list -> unit -> string list
```
```ocaml
val versions : out:string -> label:string -> string list
```
```ocaml
val write_manifest : root:string -> unit
```
```ocaml
val asset_re : Str.regexp
```
```ocaml
val local_assets : menu:string -> out:string -> unit
```
```ocaml
val cs_switch : Config.cs_side list -> string
```
```ocaml
val cs_switch_script : Config.t -> Config.cs_side list -> string
```
```ocaml
val cs_leftnav : 
  latest:string option ->
  versions:string list ->
  switch:string ->
  manual_nav:string ->
  api_nav:string ->
  string
```
```ocaml
val topdir : string -> string option
```
```ocaml
val side_for : Config.cs_side list -> string -> Config.cs_side option
```
```ocaml
val side_of : Config.cs_side list -> string -> string
```
```ocaml
val drop_prefix : string -> string -> string
```
```ocaml
val cs_current : Config.cs_side list -> string -> string
```
```ocaml
val nav_entry_paths : Config.t -> string list
```
```ocaml
val strip_index : string -> string
```
```ocaml
val current_of_page : string -> string list -> string
```
```ocaml
val md_twin : string -> string
```
```ocaml
val md_alternate : 
  md_src:string option ->
  base:string ->
  rel:string ->
  orel:string ->
  string
```
```ocaml
val nav_md_order : Config.t -> string list
```
```ocaml
val run : 
  Config.t ->
  src:string ->
  md_src:string option ->
  out:string ->
  label:string ->
  menu:string ->
  assets_dir:string ->
  local:bool ->
  set_latest:bool ->
  unit
```
```ocaml
val release : site:string -> from:string -> version:string -> unit
```