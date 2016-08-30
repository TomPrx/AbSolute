open Bot
open Bound_sig


module Make(B:BOUND) = struct

  type bound = B.t

  type kind = Strict | Large

  let sym = function
    | Large,x -> Strict,x
    | Strict,x -> Large,x

  type real_bound = kind * bound

  let ( +@ ) ((k1,b1):real_bound) ((k2,b2):real_bound) =
    (match k1,k2 with
    | Large,Large -> Large
    | _ -> Strict),(B.add_up b1 b2)

  let ( +$ ) ((k1,b1):real_bound) ((k2,b2):real_bound) =
    (match k1,k2 with
    | Large,Large -> Large
    | _ -> Strict),(B.add_down b1 b2)

  let ( -@ ) ((k1,b1):real_bound) ((k2,b2):real_bound) =
    (match k1,k2 with
    | Large,Large -> Large
    | _ -> Strict),(B.sub_up b1 b2)

  let ( -$ ) ((k1,b1):real_bound) ((k2,b2):real_bound) =
    (match k1,k2 with
    | Large,Large -> Large
    | _ -> Strict),(B.sub_down b1 b2)

  type t = real_bound * real_bound

  (* returns the half space defined by a bound and a direction.
     - true for going toward +oo
     - false for going toward -oo
     Ex: half_space (Strict,0) true gives ]0; +oo[ *)
  let half_space (k,b) dir =
    (match (k,dir) with
    | Strict, false  -> B.gt
    | Strict, true -> B.lt
    | Large , false  -> B.geq
    | Large , true -> B.leq) b

  (* check if a value is in a half space *)
  let in_half (k,b) dir v : bool = v |> half_space (k,b) dir

  (* compare two low bounds *)
  let cmp_low ((_,b1) as l1) ((_,b2) as l2) =
    if in_half l1 true b2 then -1
    else if in_half l2 true b1 then 1
    else 0

  (* compare two up bounds *)
  let cmp_up ((_,b1) as u1) ((_,b2) as u2) =
    if in_half u1 false b2 then 1
    else if in_half u2 false b1 then -1
    else 0

  let gt_low b1 b2 = cmp_low b1 b2 = 1

  let lt_low b1 b2 = cmp_low b1 b2 = -1

  let gt_up b1 b2 = cmp_up b1 b2 = 1

  let lt_up b1 b2 = cmp_up b1 b2 = -1

  (* returns the lower bound two low bounds *)
  let min_low l1 l2 = if cmp_low l1 l2 = 1 then l2 else l1

  (* returns the higher bound two low bounds *)
  let max_low l1 l2 = if cmp_low l1 l2 = 1 then l1 else l2

  (* returns the lower bound two high bounds *)
  let min_up u1 u2 = if cmp_up u1 u2 = 1 then u2 else u1

  (* returns the higher bound two high bounds *)
  let max_up u1 u2 = if cmp_up u1 u2 = 1 then u2 else u1

  (* maps empty intervals to explicit bottom *)
  let check_bot ((((_,l) as b1),((_,h)as b2)) as itv) : t bot =
    if in_half b1 true h && in_half b2 false l then Nb itv else Bot

  (* not all pairs of rationals are valid intervals *)
  let validate x =
    if check_bot x = Bot then failwith "invalid interval" else x

    (************************************************************************)
  (* CONSTRUCTORS AND CONSTANTS *)
  (************************************************************************)

  let large (x:B.t) (y:B.t) : t = validate ((Large,x),(Large,y))

  let strict (x:B.t) (y:B.t) : t = validate ((Strict,x),(Strict,y))

  let large_strict (x:B.t) (y:B.t) : t = validate ((Large,x),(Strict,y))

  let strict_large (x:B.t) (y:B.t) : t = validate ((Strict,x),(Large,y))


  let of_bound (x:B.t) : t = large x x

  let zero : t = of_bound B.zero

  let one : t = of_bound B.one

  let minus_one : t = of_bound B.minus_one

  let top : t = (Strict,B.minus_inf), (Strict,B.inf)

  let zero_one : t = large B.zero B.one

  let minus_one_zero : t = large B.minus_one B.zero

  let minus_one_one : t = large B.minus_one B.one

  let positive : t = large_strict B.zero B.inf

  let negative : t = strict_large B.minus_inf B.zero

  let of_bounds = large

  let of_ints (l:int) (h:int) : t =
    of_bounds (B.of_int_down l) (B.of_int_up h)

  let of_int (x:int) : t = of_ints x x

  let of_floats (l:float) (h:float) : t =
    of_bounds (B.of_float_down l) (B.of_float_up h)

  let of_float (x:float) : t = of_floats x x

  let hull (x:B.t) (y:B.t) : t =
    try large x y
    with Failure _ -> large y x

  (************************************************************************)
  (* PRINTING *)
  (************************************************************************)
  let to_string (((kl,l),(kh,h)):t) : string =
    Printf.sprintf
      "%c%f;%f%c"
      (if kl = Strict then ']' else '[')
      (B.to_float_down l)
      (B.to_float_up h)
      (if kh = Large then ']' else '[')

  (* printing *)
  let output chan x = output_string chan (to_string x)
  let sprint () x = to_string x
  let bprint b x = Buffer.add_string b (to_string x)
  let pp_print f x = Format.pp_print_string f (to_string x)
  let print fmt (x:t) = Format.fprintf fmt "%s" (to_string x)

   (************************************************************************)
  (* SET-THEORETIC *)
  (************************************************************************)


  (* operations *)
  (* ---------- *)
  let join ((l1,h1):t) ((l2,h2):t) : t =
    min_low l1 l2, max_up h1 h2

  let meet ((l1,h1):t) ((l2,h2):t) : t bot =
    check_bot (max_low l1 l2, min_up h1 h2)

  (* returns None if the set-union cannot be exactly represented *)
  let union (a:t) (b:t) : t option =
    if meet a b = Bot then None else Some (join a b)

  (* ---------- *)
  (* predicates *)
  (* ---------- *)
  let equal ((l1,h1):t) ((l2,h2):t) : bool =
    let equal_bound (k1,b1) (k2,b2) =
      k1 = k2 && B.equal b1 b2
    in equal_bound l1 l2 && equal_bound h1 h2

  (* i1 in i2*)
  let subseteq i1 i2 : bool =
    join i1 i2 |> equal i2

  let contains ((l,h):t) (x:B.t) : bool =
    in_half l true x && in_half h false x

  let intersect i1 i2 : bool =
    meet i1 i2 <> Bot

  let is_finite ((_,x) : real_bound) : bool =
    B.classify x = B.FINITE

  let is_bounded ((l,h):t) =
    is_finite l && is_finite h

  let is_singleton ((l,h):t) : bool =
    is_finite l && B.equal (snd l) (snd h)

  (* length of the intersection (>= 0) *)
  let range (((_,l),(_,h)): t) = B.sub_up h l

  let overlap i1 i2 =
    match meet i1 i2 with
    | Bot -> B.zero
    | Nb i -> range i

  let magnitude (((_,l),(_,h)): t) : B.t =
    B.max (B.abs l) (B.abs h)

  let mean (((_,l) as low, ((_,h) as high)):t) : B.t list =
    let res =
      match is_finite low, is_finite high with
      | true,true -> B.div_up (B.add_up l h) B.two
      | true,false ->
         if B.sign l < 0 then B.zero
         else if B.sign l = 0 then B.one
         else B.mul_up l B.two
      | false,true ->
         if B.sign h > 0 then B.zero
         else if B.sign h = 0 then B.minus_one
         else B.mul_down h B.two
      | false,false -> B.zero
    in [res]

  (* splits in two, around m *)
  let split ((l,h):t) (m:bound list) : (t bot) list =
    let rec aux acc cur (bounds:bound list) =
      match bounds with
      |  hd::tl ->
	       let itv = check_bot (cur,(Large,hd)) in
	       aux (itv::acc) (Strict,hd) tl
      | [] ->
	       let itv = check_bot (cur,h) in
	       itv::acc
    in aux [] l m

  (* integer optimized verison *)
  let split_integer ((l,h):t) (m:bound list) : (t bot) list =
    let rec aux acc cur (bounds:bound list) =
      match bounds with
      |  hd::tl ->
         let int_down,int_up =
           let a,b = B.floor hd, B.ceil hd in
           if B.equal a b then a,(B.add_up b B.one)
           else a,b
         in
	       let itv = check_bot (cur,(Large,int_down)) in
	       aux (itv::acc) (Strict,int_up) tl
      | [] -> (check_bot (cur,h))::acc
    in aux [] l m

  let prune ((l,h):t) ((l',h'):t) : t list * t  =
    match (gt_low l' l),(lt_up h' h) with
    | true , true -> [(l,(sym l'));((sym h'),h)],(l',h')
    | true , false  -> [(l,(sym l'))],(l,h)
    | false, true -> [((sym h'),h)],(l,h)
    | false, false  -> [],(l,h)

  (************************************************************************)
  (* INTERVAL ARITHMETICS (FORWARD EVALUATION) *)
  (************************************************************************)

  let neg (((kl,l),(kh,h)):t) : t = (kl,B.neg h), (kh,B.neg l)

  let abs (((kl,l),(kh,h)):t) : t = failwith "todo"

  let add ((l1,h1):t) ((l2,h2):t) : t = l1 +$ l2, h1 +@ h2

  let sub ((l1,h1):t) ((l2,h2):t) : t = l1 -$ h2, h1 +@ l2

  let mul = failwith " todo "

  let div (i1:t) (i2:t) : t bot * bool = failwith "todo"

  let sqrt ((l,h):t) : t bot = failwith "todo"

  let pow (i1:t) (i2:t) : t bot * bool = failwith "todo"

  let cos (((kl,l),(kh,h)):t) : t = (kl,B.neg h), (kh,B.neg l)

  let sin (((kl,l),(kh,h)):t) : t = (kl,B.neg h), (kh,B.neg l)

  (************************************************************************)
  (* FILTERING (TEST TRANSFER FUNCTIONS) *)
  (************************************************************************)

  let bobot a b c d =
    merge_bot2 (check_bot (a,b)) (check_bot (c,d))

  let filter_leq ((l1,h1):t) ((l2,h2):t) : (t * t) bot =
    bobot l1 (min_up h1 h2) (max_low l1 l2) h2

  let filter_geq ((l1,h1):t) ((l2,h2):t) : (t*t) bot =
    bobot (max_low l1 l2) h1 l2 (min_up h1 h2)

  let filter_lt ((l1,h1):t) ((l2,h2):t) : (t*t) bot =
    bobot l1 (min_up h1 (sym h2)) (max_low (sym l1) l2) h2

  let filter_gt  ((l1,h1):t) ((l2,h2):t) : (t*t) bot =
    bobot (max_low l1 (sym l2)) h1 l2 (min_up (sym h1) h2)

  let filter_eq (i1:t) (i2:t) : (t*t) bot =
    lift_bot (fun x -> x,x) (meet i1 i2)

  let filter_neq ((l1,_) as i1:t) ((l2,_) as i2:t) : (t*t) bot =
    if is_singleton i1 && is_singleton i2 && equal i1 i2 then Bot
    else Nb (i1,i2)

  let filter_lt_int ((l1,h1):t) ((l2,h2):t) : (t*t) bot =
    bobot
      l1
      (min_up h1 (h2 +@ (Large,B.one)))
      (max_low (l1 +$ (Large,B.one)) l2)
      h2

  let filter_gt_int ((l1,h1):t) ((l2,h2):t) : (t*t) bot =
    bobot
      (max_low l1 (l2 +$ (Large,B.one))) h1
      l2 (min_up (h1 -@ (Large,B.one)) h2)

  let filter_neq_int ((l1,h1):t) ((l2,h2):t) : (t*t) bot =
    failwith "todo"
end