# Module `Wodoc.Util`

Small helpers shared by wodoc's modules.

```ocaml
val read_file : string -> string
```
`read_file f` is the contents of the file `f`.

```ocaml
val write_file : string -> string -> unit
```
`write_file f s` writes `s` to the file `f`, replacing its contents.

```ocaml
val is_url : string -> bool
```
`is_url p` is `true` if `p` is an `http://` or `https://` URL.
