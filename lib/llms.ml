(* Generate the LLM-friendly index files (llms.txt / llms-full.txt) for a built
   project doc, from the Markdown twin tree {!Build} places in the output. The
   index follows the llms.txt convention (llmstxt.org): an H1 with the project
   name, a blockquote summary, then file-list sections. We classify the produced
   .md pages into a Manual section (lowercase-named pages: the hand-written .mld
   manual) and an API section (Capitalised module pages), so an AI sees the
   structure at a glance and can fetch any page; llms-full.txt is every page
   concatenated for single-shot ingestion. *)

let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let write_file f s =
  let oc = open_out_bin f in
  output_string oc s; close_out oc

(* relative ".md" paths under [out] (the version root), sorted *)
let md_files out =
  let acc = ref [] in
  let rec walk rel =
    let abs = if rel = "" then out else Filename.concat out rel in
    if try Sys.is_directory abs with _ -> false
    then
      Array.iter
        (fun e -> walk (if rel = "" then e else Filename.concat rel e))
        (Sys.readdir abs)
    else if Filename.check_suffix rel ".md"
    then acc := rel :: !acc
  in
  if Sys.file_exists out then walk "";
  List.sort compare !acc

(* the first non-empty line is the page's "# Title"; drop the leading "# " *)
let h1_title content fallback =
  let lines = String.split_on_char '\n' content in
  let rec first = function
    | l :: t ->
        let l = String.trim l in
        if l = ""
        then first t
        else if String.starts_with ~prefix:"# " l
        then String.sub l 2 (String.length l - 2)
        else fallback
    | [] -> fallback
  in
  first lines

(* the first ordinary paragraph (skip the H1 and blank lines); a one-line summary *)
let first_para content =
  let lines = String.split_on_char '\n' content in
  let rec go seen_h1 = function
    | l :: t ->
        let s = String.trim l in
        if s = ""
        then go seen_h1 t
        else if String.starts_with ~prefix:"#" s
        then go true t
        else if seen_h1
        then Some s
        else go seen_h1 t
    | [] -> None
  in
  go false lines

(* a module page is Capitalised (OCaml module convention); everything else
   (lowercase-named pages: index, the manual .mld) is "manual" *)
let is_api rel =
  let b = Filename.basename rel in
  String.length b > 0 && b.[0] >= 'A' && b.[0] <= 'Z'

let write ~out ~title ~landing ~order =
  let files = md_files out in
  if files = []
  then ()
  else begin
    let summary =
      match landing with
      | Some l when Sys.file_exists (Filename.concat out l) -> (
        match first_para (read_file (Filename.concat out l)) with
        | Some s -> s
        | None -> title ^ " — part of the Ocsigen Web framework (OCaml).")
      | _ -> title ^ " — part of the Ocsigen Web framework (OCaml)."
    in
    (* preferred order: nav order first, then the rest alphabetically *)
    let rank p =
      match List.find_index (String.equal p) order with
      | Some i -> i
      | None -> max_int
    in
    let files =
      List.stable_sort
        (fun a b ->
           let c = compare (rank a) (rank b) in
           if c <> 0 then c else compare a b)
        files
    in
    let manual, api = List.partition (fun f -> not (is_api f)) files in
    let title_of rel = h1_title (read_file (Filename.concat out rel)) rel in
    (* llms.txt: the structured index *)
    let b = Buffer.create 4096 in
    let add s = Buffer.add_string b s; Buffer.add_char b '\n' in
    add (Printf.sprintf "# %s" title);
    add "";
    add (Printf.sprintf "> %s" summary);
    let section heading items =
      if items <> []
      then begin
        add "";
        add (Printf.sprintf "## %s" heading);
        List.iter
          (fun rel -> add (Printf.sprintf "- [%s](%s)" (title_of rel) rel))
          items
      end
    in
    section "Manual" manual;
    section "API" api;
    write_file (Filename.concat out "llms.txt") (Buffer.contents b);
    (* llms-full.txt: every page concatenated for single-shot ingestion *)
    let f = Buffer.create 65536 in
    Buffer.add_string f (Printf.sprintf "# %s\n\n> %s\n" title summary);
    List.iter
      (fun rel ->
         Buffer.add_string f "\n\n---\n\n";
         Buffer.add_string f (String.trim (read_file (Filename.concat out rel)));
         Buffer.add_char f '\n')
      (manual @ api);
    write_file (Filename.concat out "llms-full.txt") (Buffer.contents f)
  end
