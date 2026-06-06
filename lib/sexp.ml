(* A tiny S-expression reader for wodoc's declarative project config — just
   enough to parse dune-style stanzas: parenthesised lists, bare atoms,
   double-quoted strings (with backslash escapes), and semicolon line comments.
   No external dependency. *)

type t = Atom of string | List of t list

exception Error of string

let parse s =
  let n = String.length s in
  let i = ref 0 in
  let error msg = raise (Error (Printf.sprintf "%s at offset %d" msg !i)) in
  let is_space c = c = ' ' || c = '\t' || c = '\n' || c = '\r' in
  let is_delim c = is_space c || c = '(' || c = ')' || c = ';' in
  let rec skip_ws () =
    if !i < n then
      if is_space s.[!i] then (incr i; skip_ws ())
      else if s.[!i] = ';'
      then (
        while !i < n && s.[!i] <> '\n' do incr i done;
        skip_ws ())
  in
  let read_string () =
    incr i; (* opening quote *)
    let b = Buffer.create 16 in
    let rec go () =
      if !i >= n then error "unterminated string"
      else
        match s.[!i] with
        | '"' -> incr i
        | '\\' when !i + 1 < n ->
            Buffer.add_char b s.[!i + 1];
            i := !i + 2;
            go ()
        | c -> Buffer.add_char b c; incr i; go ()
    in
    go ();
    Buffer.contents b
  in
  let read_atom () =
    let start = !i in
    while !i < n && not (is_delim s.[!i]) do incr i done;
    String.sub s start (!i - start)
  in
  let rec read_sexp () =
    skip_ws ();
    if !i >= n then error "unexpected end of input"
    else
      match s.[!i] with
      | '(' ->
          incr i;
          let items = read_list () in
          List items
      | ')' -> error "unexpected )"
      | '"' -> Atom (read_string ())
      | _ -> Atom (read_atom ())
  and read_list () =
    skip_ws ();
    if !i >= n then error "unterminated list"
    else if s.[!i] = ')'
    then (incr i; [])
    else
      let hd = read_sexp () in
      hd :: read_list ()
  in
  (* a config file is a sequence of top-level stanzas; wrap them in one list *)
  let rec top acc =
    skip_ws ();
    if !i >= n then List.rev acc else top (read_sexp () :: acc)
  in
  top []

(* ---- small accessors ---- *)

let atom = function Atom a -> a | List _ -> raise (Error "expected atom")

(* the stanzas named [key] at top level: each is [(key arg ...)] -> [arg ...] *)
let fields key stanzas =
  List.filter_map
    (function
      | List (Atom k :: rest) when k = key -> Some rest
      | _ -> None)
    stanzas

(* the single [(key v)] -> [v] (as raw sexp), or [None] *)
let field key stanzas =
  match fields key stanzas with [ v ] :: _ -> Some v | _ -> None

let field_atom key stanzas = Option.map atom (field key stanzas)

let field_atom_default key default stanzas =
  match field_atom key stanzas with Some v -> v | None -> default

(* all atoms of [(key a b c)] flattened across occurrences *)
let field_atoms key stanzas =
  List.concat_map (List.map atom) (fields key stanzas)
