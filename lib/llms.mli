(** Generate the LLM-friendly index files for a built project doc, from the
    Markdown twin tree that {!Build} produces in the output directory.

    Follows the [llms.txt] convention (llmstxt.org): a single H1 with the project
    name, a blockquote summary, then sections listing the Markdown pages. *)

val write :
   out:string
  -> title:string
  -> landing:string option
  -> order:string list
  -> unit
(** [write ~out ~title ~landing ~order] writes, at the version root [out]:
    - [llms.txt]: the index — [# title], a [>] blockquote summary (the first
      paragraph of the [landing] Markdown page when given, else a generic line),
      then a [## Manual] and a [## API] section listing every [.md] page found
      under [out] (manual = lowercase-named pages, API = Capitalised modules),
      each as [- \[H1 title\](relative path)];
    - [llms-full.txt]: all those pages concatenated, for single-shot ingestion.

    [order] is a list of [.md] paths giving the preferred (project-nav) ordering;
    pages absent from it follow alphabetically. Does nothing if no [.md] page
    exists under [out] (e.g. markdown generation was skipped). *)
