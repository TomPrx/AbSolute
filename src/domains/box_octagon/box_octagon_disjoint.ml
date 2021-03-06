open Box_dom
open Octagon
open Csp
open Abstract_domain
open Box_representation

module type Box_oct_rep_sig = functor (Oct_rep: Representation_sig) ->
sig
  type t = {
    box_rep: Box_rep.t;
    oct_rep: Oct_rep.t;
  }
  type var_kind = BoxKind of Box_rep.var_kind | OctKind of Oct_rep.var_kind
  type var_id = BoxVar of Box_rep.var_id | OctVar of Oct_rep.var_id
  type reified_octagonal = Box_rep.var_id * Oct_rep.rconstraint list
  type rconstraint =
    BoxConstraint of Box_rep.rconstraint
  | OctConstraint of Oct_rep.rconstraint
  | ReifiedConstraint of reified_octagonal

  val empty: t
  val extend: t -> (Csp.var * var_id) -> t
  val to_logic_var: t -> var_id -> var
  val to_abstract_var: t -> var -> var_id
  val rewrite: t -> bconstraint -> rconstraint list
  (* This is a temporary function. We should generalized Representation_sig to formula rather than only constraint. *)
  val rewrite_reified: t -> var -> bconstraint list -> rconstraint list
  val relax: t -> bconstraint -> rconstraint list
  val negate: rconstraint -> rconstraint
end

module Box_oct_rep(Oct_rep: Representation_sig) =
struct
  type t = {
    box_rep: Box_rep.t;
    oct_rep: Oct_rep.t;
  }
  type var_kind = BoxKind of Box_rep.var_kind | OctKind of Oct_rep.var_kind
  type var_id = BoxVar of Box_rep.var_id | OctVar of Oct_rep.var_id
  type reified_octagonal = Box_rep.var_id * Oct_rep.rconstraint list
  type rconstraint =
    BoxConstraint of Box_rep.rconstraint
  | OctConstraint of Oct_rep.rconstraint
  | ReifiedConstraint of reified_octagonal

  let empty = {box_rep=Box_rep.empty; oct_rep=Oct_rep.empty}
  let extend repr = function
    | (v, BoxVar bv) -> { repr with box_rep=Box_rep.extend repr.box_rep (v, bv)}
    | (v, OctVar ov) -> { repr with oct_rep=Oct_rep.extend repr.oct_rep (v, ov)}

  let to_logic_var repr = function
    | BoxVar(id) -> Box_rep.to_logic_var repr.box_rep id
    | OctVar(id) -> Oct_rep.to_logic_var repr.oct_rep id

  let to_abstract_var repr v =
    try BoxVar (Box_rep.to_abstract_var repr.box_rep v)
    with Not_found -> OctVar (Oct_rep.to_abstract_var repr.oct_rep v)

  let is_defined_over repr (e1,op,e2) is_inside =
    List.for_all is_inside (get_vars_bexpr (Cmp (op,e1,e2)))

  let is_box_var repr v =
    match to_abstract_var repr v with
    | BoxVar _ -> true
    | OctVar _ -> false

  let is_defined_over_box repr c = is_defined_over repr c (is_box_var repr)
  let is_defined_over_oct repr c = is_defined_over repr c (fun v -> not (is_box_var repr v))

  let rewrite repr c =
    if is_defined_over_box repr c then
      List.map (fun c -> BoxConstraint c) (Box_rep.rewrite repr.box_rep c)
    else if is_defined_over_oct repr c then
      List.map (fun c -> OctConstraint c) (Oct_rep.rewrite repr.oct_rep c)
    else
      raise (Wrong_modelling
        ("Box_octagon_disjoint: Constraint defined on variables from both box and octagon are not supported in this abstract domain.\n" ^
        "You should communicate equivalence between abstract domains with reified constraints."))

  (* This is a temporary function. We should generalized Representation_sig to formula rather than only constraint. *)
  let rewrite_reified repr b conjunction =
    let try_rewrite all c =
      let rewritten_c = Oct_rep.rewrite repr.oct_rep c in
      if (List.length rewritten_c)=0 then
        raise (Wrong_modelling ("The abstract domain `Box_octagon_disjoint` expects octagonal reified constraints, but `" ^
               (string_of_bconstraint c) ^ "` could not be rewritten as an octagonal constraint."))
      else
        all@rewritten_c in
    let constraints = List.fold_left try_rewrite [] conjunction in
    let b = Box_rep.to_abstract_var repr.box_rep b in
    [ReifiedConstraint (b, constraints)]

  let relax = rewrite

  let negate = function
    | BoxConstraint c -> BoxConstraint (Box_rep.negate c)
    | OctConstraint c -> OctConstraint (Oct_rep.negate c)
    | ReifiedConstraint(b, conjunction) -> failwith "Negation of reified constraints is not yet supported."

end

module type Box_octagon_disjoint_sig =
sig
  module B : Bound_sig.BOUND
  module R : Representation_sig
  type t
  type bound = B.t
  val empty: t
  val extend: t -> R.var_kind -> (t * R.var_id)
  val project: t -> R.var_id -> (B.t * B.t)
  val lazy_copy: t -> int -> t list
  val copy: t -> t

  (** This closure filters the box and octagon with regards to the (reified) constraints in `box_oct`.
      Besides reducing the domain of the variables, the entailed constraints are removed from `box_oct`. *)
  val closure: t -> t
  val weak_incremental_closure: t -> R.rconstraint -> t
  val entailment: t -> R.rconstraint -> kleene
  val split: t -> t list
  val volume: t -> float
  val state_decomposition: t -> kleene
  val print: R.t -> Format.formatter -> t -> unit
end

module Make
  (BOX: Box_functor)
  (Octagon: Octagon_sig) =
struct
  module B = Octagon.B
  module Box=BOX(B)
  type bound = B.t
  module R = Box_oct_rep(Octagon.R)

  type t = {
    box : Box.t;
    octagon: Octagon.t;
    reified_octagonal: R.reified_octagonal list;
  }

  let empty = {
    box=Box.empty;
    octagon=Octagon.empty;
    reified_octagonal=[];
  }

  let extend box_oct = function
  | R.BoxKind k ->
      let (box, id) = Box.extend box_oct.box k in
      { box_oct with box=box }, (R.BoxVar id)
  | R.OctKind k ->
      let (oct, id) = Octagon.extend box_oct.octagon k in
      { box_oct with octagon=oct }, (R.OctVar id)

  let volume box_oct =
    let box_vol = (Box.volume box_oct.box) in
    let oct_vol = (Octagon.volume box_oct.octagon) in
    if box_vol = 1. && oct_vol = 1. then 1.
    else if box_vol = 0. || oct_vol = 0. then 0.
    else box_vol +. oct_vol

  let lazy_copy box_oct n = List.map2
    (fun box octagon -> {box_oct with box; octagon})
    (Box.lazy_copy box_oct.box n)
    (Octagon.lazy_copy box_oct.octagon n)
  let copy box_oct = {box_oct with box=Box.copy box_oct.box; octagon=Octagon.copy box_oct.octagon}
  let entailment box_oct = function
    | R.BoxConstraint(c) -> Box.entailment box_oct.box c
    | R.OctConstraint(c) -> Octagon.entailment box_oct.octagon c
    | R.ReifiedConstraint(b, c) -> failwith "entailment of reified constraint is not implemented."

  let entailment_of_reified box_oct conjunction =
    let entailed = List.map (Octagon.entailment box_oct.octagon) conjunction in
    and_reified entailed

  let propagate_negation_conjunction box_oct (b, conjunction) =
    match entailment_of_reified box_oct conjunction with
    | False, _ -> box_oct
    | True, _ -> raise Bot.Bot_found
    | Unknown, Some(u) ->
        let unknown = List.nth conjunction u in
        let neg_unknown = Octagon.R.negate unknown in
        { box_oct with octagon=Octagon.weak_incremental_closure box_oct.octagon neg_unknown }
    | Unknown, None ->
        { box_oct with reified_octagonal=(b, conjunction)::box_oct.reified_octagonal }

  (* Propagate the reified constraints.
     Entailed reified constraints are removed from `box_oct`. *)
  let propagate_reified_octagonal box_oct (b, conjunction) =
    let itv = Box.project_itv box_oct.box b in
    if Box.I.is_singleton itv then
      let (value,_) = Box.I.to_range itv in
      if B.equal B.one value then
        { box_oct with octagon=List.fold_left Octagon.weak_incremental_closure box_oct.octagon conjunction }
      else if B.equal B.zero value then
        propagate_negation_conjunction box_oct (b, conjunction)
      else failwith "Reified boolean should be equal to 0 or 1."
    else
      match fst (entailment_of_reified box_oct conjunction) with
      | False ->
       { box_oct with box=(Box.weak_incremental_closure box_oct.box (Var b, EQ, constant_zero)) }
      | True ->
       { box_oct with box=(Box.weak_incremental_closure box_oct.box (Var b, EQ, constant_one)) }
      | Unknown -> { box_oct with reified_octagonal=(b, conjunction)::box_oct.reified_octagonal }

  (** Filter all the reified octagonal constraints.
      See also `propagate_reified_octagonal`. *)
  let reified_closure box_oct =
    List.fold_left propagate_reified_octagonal
      {box_oct with reified_octagonal=[]}
      box_oct.reified_octagonal

  let rec propagate vol box_oct =
    let box_oct = reified_closure box_oct in
    let box_oct = { box_oct with box=Box.closure box_oct.box } in
    (* let box_oct = reified_closure box_oct in *)
    let box_oct = { box_oct with octagon=Octagon.closure box_oct.octagon } in
    let vol' = volume box_oct in
    if vol <> vol' then
      propagate vol' box_oct
    else
      box_oct

  let closure (box_oct:t) =
    (* Apply all the possible constraints from the splitting strategy. *)
    let box_oct = { box_oct with octagon=Octagon.closure box_oct.octagon } in
    propagate (volume box_oct) box_oct

  let weak_incremental_closure box_oct =
    function
    | R.BoxConstraint(c) -> { box_oct with box=Box.weak_incremental_closure box_oct.box c }
    | R.OctConstraint(c) -> { box_oct with octagon=Octagon.weak_incremental_closure box_oct.octagon c }
    | R.ReifiedConstraint(b, c) -> { box_oct with reified_octagonal=(b, c)::box_oct.reified_octagonal}

  let incremental_closure_octagon box_oct c = closure (weak_incremental_closure box_oct c)

  let split box_oct =
    let branches = List.map (fun octagon -> { box_oct with octagon=octagon }) (Octagon.split box_oct.octagon) in
    if (List.length branches) = 0 then
      let branches = Box.split box_oct.box in
      let octagons = Octagon.lazy_copy box_oct.octagon (List.length branches) in
      List.map2 (fun box octagon -> { box_oct with box=box; octagon=octagon }) branches octagons
    else
      branches

  let state_decomposition box_oct =
    match Octagon.state_decomposition box_oct.octagon, Box.state_decomposition box_oct.box with
    | True, True when (List.length box_oct.reified_octagonal) = 0 -> True
    | False, _ | _, False -> False
    | _ -> Unknown

  let project box_oct = function
    | R.BoxVar id -> Box.project box_oct.box id
    | R.OctVar id -> Octagon.project box_oct.octagon id

  (* TODO: Print the reified constraints. The first step would be to retrieve the variables' names in the reified constraint. *)
  let print repr fmt box_oct =
  begin
    Box.print R.(repr.box_rep) fmt box_oct.box;
    Format.fprintf fmt "\n";
    Octagon.print R.(repr.oct_rep) fmt box_oct.octagon;
    Format.fprintf fmt "\n";
  end
end
