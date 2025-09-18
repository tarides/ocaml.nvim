type t = A | B_of_t of t

let f n : t =
  match n with
  | 0 -> _
  | 1 -> _
  | 2 -> _

let f1 n : t =
  match n with
  | 0 -> _
  | 1 -> _
  | _ -> _
