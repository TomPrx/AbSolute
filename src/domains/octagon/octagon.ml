open Csp

type plane = int * int
type key = int * plane

let if_rotated_else : key -> 'a -> 'a -> 'a = fun (v, (d1,d2)) then_b else_b ->
  if d1 <> d2 && (d1 = v || d2 = v) then then_b else else_b

(* Canonical plane *)
let cplane = (0,0)

let well_formed_plane (d1,d2) = ((d1 = 0 || d1 <> d2) && d1 <= d2)
let check_well_formed_plane plane = assert (well_formed_plane plane)

let lb_pos (v, (d1, d2)) =
  check_well_formed_plane (d1,d2);
  (* `v` correspond to the rotated plane along the axis `d1`. *)
  if v = d1 && d1 <> d2 then (2*d2),(2*d1+1)
  (* and here along the axis `d2`. *)
  else if v = d2 && d1 <> d2 then (2*d2),(2*d1)
  (* Non-rotated dimension, or canonical plane. *)
  else (v*2),(v*2+1)

(* Similar to `lb_pos`. *)
let ub_pos (v, (d1,d2)) =
  check_well_formed_plane (d1,d2);
  if v = d1 && d1 <> d2 then (2*d2+1),(2*d1)
  else if v = d2 && d1 <> d2 then (2*d2+1),(2*d1+1)
  else (v*2+1),(v*2)

module type IntervalViewDBM = sig
  module B : Bound_sig.BOUND
  type bound = B.t
  type itv

  val dbm_to_lb : key -> bound -> bound
  val dbm_to_ub : key -> bound -> bound
  val lb_to_dbm : key -> bound -> bound
  val ub_to_dbm : key -> bound -> bound

  val itv_to_range : itv -> (bound * bound)
  val range_to_itv : bound -> bound -> itv
end

module FloatIntervalDBM = struct
  module B = Bound_float
  module I = Trigo.Make(Itv.Itv(B))
  type bound = B.t
  type itv = I.t

  (* Rules for coping with rounding when transferring from DBM to BOX:
    * From BOX to DBM: every number is rounded UP because these numbers only decrease during the Floyd Warshall algorithm.
    * From DBM to BOX: the number is rounded DOWN for lower bound and UP for upper bound.

   To simplify the treatment (and improve soundness), we use interval arithmetic: (sqrt 2) is interpreted as the interval [sqrt_down 2, sqrt_up 2].
   Further operations are performed on this interval, and we chose the lower or upper bound at the end depending on what we need.
  *)
  let two_it = I.of_float (B.two)
  let minus_two_it = I.neg two_it
  let sqrt2_it = I.of_floats (B.sqrt_down B.two) (B.sqrt_up B.two)
  let minus_sqrt2_it = I.neg sqrt2_it
  let lb_it i = let (l,_) = I.to_float_range i in l
  let ub_it i = let (_,u) = I.to_float_range i in u

  let dbm_to_lb k v =
    let vi = I.of_float v in
    let divider = if_rotated_else k minus_sqrt2_it minus_two_it in
    lb_it (Bot.nobot (I.div vi divider))

  let dbm_to_ub k v =
    let vi = I.of_float v in
    let divider = if_rotated_else k sqrt2_it two_it in
    ub_it (Bot.nobot (I.div vi divider))

  let lb_to_dbm k v =
    let multiplier = if_rotated_else k minus_sqrt2_it minus_two_it in
    lb_it (I.mul (I.of_float v) multiplier)

  let ub_to_dbm k v =
    let multiplier = if_rotated_else k sqrt2_it two_it in
    ub_it (I.mul (I.of_float v) multiplier)

  let itv_to_range = I.to_float_range
  let range_to_itv = I.of_floats
end

module RationalIntervalDBM = struct
  module B = Bound_rat
  module I = Trigo.Make(Itv.Itv(B))
  type bound = B.t
  type itv = I.t

  let of_int : int -> bound = Bound_rat.of_int_up

  let sqrt2_it = I.of_rats (B.sqrt_down B.two) (B.sqrt_up B.two)
  let minus_sqrt2_it = I.neg sqrt2_it
  let lb_it i = let (l,_) = I.to_rational_range i in l
  let ub_it i = let (_,u) = I.to_rational_range i in u

  let dbm_to_lb k v =
    let vi = I.of_rat v in
    let in_plane = lb_it (Bot.nobot (I.div vi minus_sqrt2_it)) in
    if_rotated_else k in_plane (B.div_down v B.minus_two)

  let dbm_to_ub k v =
    let vi = I.of_rat v in
    let in_plane = ub_it (Bot.nobot (I.div vi sqrt2_it)) in
    if_rotated_else k in_plane (B.div_up v B.two)

  let lb_to_dbm k v =
    let in_plane = lb_it (I.mul (I.of_rat v) minus_sqrt2_it) in
    if_rotated_else k in_plane (B.mul_down v B.minus_two)

  let ub_to_dbm k v =
    let in_plane = ub_it (I.mul (I.of_rat v) sqrt2_it) in
    if_rotated_else k in_plane (B.mul_up v B.two)

  let itv_to_range = I.to_rational_range
  let range_to_itv = I.of_rats
end

module IntegerIntervalDBM = struct
  module B = Bound_int
  module I = Trigo.Make(Itv.Itv(B))
  type bound = B.t
  type itv = I.t

  let dbm_to_lb k v =
    B.of_rat_down (RationalIntervalDBM.dbm_to_lb k (RationalIntervalDBM.of_int v))
  let dbm_to_ub k v =
    B.of_rat_up (RationalIntervalDBM.dbm_to_ub k (RationalIntervalDBM.of_int v))
  let lb_to_dbm k v =
    B.of_rat_up (RationalIntervalDBM.lb_to_dbm k (RationalIntervalDBM.of_int v))
  let ub_to_dbm k v =
    B.of_rat_up (RationalIntervalDBM.ub_to_dbm k (RationalIntervalDBM.of_int v))

  let itv_to_range (l,u) =
    let (l,u) = I.to_float_range (l,u) in
    (int_of_float l, int_of_float (ceil u))

  let range_to_itv = I.of_ints
end

module type Octagon_sig =
sig
  type t
  type bound
  val init: Csp.var list -> Csp.bconstraint list -> ((bool * Csp.bconstraint) list * t)
  val empty: t
  val extend_one: t -> Csp.var -> t
  val update: t -> Octagonal_rewriting.octagonal_constraint -> unit
  val join_constraint: t -> Csp.bconstraint -> bool
  val set_lb: t -> key -> bound -> unit
  val set_ub: t -> key -> bound -> unit
  val lb: t -> key -> bound
  val ub: t -> key -> bound
  val closure: t -> unit
  val dbm_as_list: t -> bound list
end

module Make
  (IntervalView: IntervalViewDBM)
  (Closure: Closure.Closure_sig with module DBM = Dbm.Make(IntervalView.B))
  (Rewriter: Octagonal_rewriting.Rewriter_sig) =
struct
  module DBM = Closure.DBM

  include IntervalView
  include Rewriter

  module Env = Tools.VarMap
  module REnv = Mapext.Make(struct
    type t=key
    let compare = compare end)

  (* We keep a bijection between AbSolute variable names (string) and the DBM key.
     Invariant: For all key, we have: `key = REnv.find (Env.find env key) renv`. *)
  type t = {
    dbm: DBM.t;
    (* maps each variable name to its `key` in the dbm. *)
    env : key Env.t;
    (* reversed mapping of `env`. *)
    renv : string REnv.t;
  }

  let set_lb o k v = DBM.set o.dbm (lb_pos k) (lb_to_dbm k v)
  let set_ub o k v = DBM.set o.dbm (ub_pos k) (ub_to_dbm k v)
  let lb o k = dbm_to_lb k (DBM.get o.dbm (lb_pos k))
  let ub o k = dbm_to_ub k (DBM.get o.dbm (ub_pos k))

  let empty = {
    dbm=DBM.empty;
    env=Env.empty;
    renv=REnv.empty;
  }

  let extend_one octagon var =
    let key = (DBM.dimension octagon.dbm, cplane) in
    {
      dbm=DBM.extend_one octagon.dbm;
      env=Env.add var key octagon.env;
      renv=REnv.add key var octagon.renv;
    }

  let update octagon oc =
    let open Octagonal_rewriting in
    let index_of (sign, v) =
      let (d,_) = Env.find v octagon.env in
      match sign with
      | Positive -> d*2+1
      | Negative -> d*2 in
    DBM.set octagon.dbm (index_of oc.x, index_of oc.y) (B.of_rat_up oc.c)

  let join_constraint octagon c =
    let iter_oct = List.iter (update octagon) in
    match rewrite c with
    | [] ->
        (match relax c with
        | [] -> false
        | cons -> (iter_oct cons; false))
    | cons -> (iter_oct cons; true)

  let init vars constraints =
    let octagon = List.fold_left extend_one empty vars in
    let constraints = List.filter (is_defined_over vars) constraints in
    (List.map (fun c -> (join_constraint octagon c, c)) constraints, octagon)

  let dbm_as_list octagon = DBM.to_list octagon.dbm

  (** Reexported functions from the parametrized modules. *)
  let closure octagon = Closure.closure octagon.dbm
  let is_consistent octagon = Closure.is_consistent octagon.dbm
end

module DBM_Z = Dbm.Make(Bound_int)
module OctagonZ = Make
  (IntegerIntervalDBM)
  (Closure.ClosureZ(DBM_Z))
  (Octagonal_rewriting.RewriterZ)

module DBM_Q = Dbm.Make(Bound_rat)
module OctagonQ = Make
  (RationalIntervalDBM)
  (Closure.ClosureQ(DBM_Q))
  (Octagonal_rewriting.RewriterQF)

module DBM_F = Dbm.Make(Bound_float)
module OctagonF = Make
  (FloatIntervalDBM)
  (Closure.ClosureF(DBM_F))
  (Octagonal_rewriting.RewriterQF)