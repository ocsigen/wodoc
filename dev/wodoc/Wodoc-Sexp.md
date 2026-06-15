
# Module `Wodoc.Sexp`

```ocaml
type t = 
  | Atom of string
  | List of t list
```
```ocaml
exception Error of string
```
```ocaml
val parse : string -> t list
```
```ocaml
val atom : t -> string
```
```ocaml
val fields : string -> t list -> t list list
```
```ocaml
val field : string -> t list -> t option
```
```ocaml
val field_atom : string -> t list -> string option
```
```ocaml
val field_atom_default : string -> string -> t list -> string
```
```ocaml
val field_atoms : string -> t list -> string list
```