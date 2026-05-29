let mopen = "{%wodoc:"
let mclose = "%}"

let find s sub from =
  let len = String.length s and sl = String.length sub in
  let rec go j =
    if j + sl > len
    then None
    else if String.sub s j sl = sub
    then Some j
    else go (j + 1)
  in
  go from

let string s =
  let out = Buffer.create (String.length s) in
  let len = String.length s in
  let i = ref 0 in
  while !i < len do
    match find s mopen !i with
    | None ->
        Buffer.add_substring out s !i (len - !i);
        i := len
    | Some start -> (
        Buffer.add_substring out s !i (start - !i);
        let cstart = start + String.length mopen in
        match find s mclose cstart with
        | None ->
            Buffer.add_substring out s start (len - start);
            i := len
        | Some cend ->
            let directive = String.sub s cstart (cend - cstart) in
            Buffer.add_string out "{%html:<!--wodoc:";
            Buffer.add_string out directive;
            Buffer.add_string out "-->%}";
            i := cend + String.length mclose)
  done;
  Buffer.contents out
