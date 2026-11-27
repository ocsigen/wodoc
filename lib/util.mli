(** Small helpers shared by wodoc's modules. *)

val read_file : string -> string
(** [read_file f] is the contents of the file [f]. *)

val write_file : string -> string -> unit
(** [write_file f s] writes [s] to the file [f], replacing its contents. *)

val is_url : string -> bool
(** [is_url p] is [true] if [p] is an [http://] or [https://] URL. *)

val mkdir_p : string -> unit
(** [mkdir_p dir] creates [dir] and its missing parents, like [mkdir -p]. *)

val files : string -> string list
(** [files dir] is the regular files below the directory [dir], at any depth,
    as paths relative to [dir], sorted within each directory. Symbolic links
    are followed, each directory once; an entry that cannot be read (a dangling
    link) is skipped with a warning on [stderr]. [files dir] is empty when
    [dir] is not a directory. *)
