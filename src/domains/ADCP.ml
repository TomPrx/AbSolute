open Apron
open Apron_utils

(**
 * Module for the Box Abstract Domains for Constraint Programming.
 *)
module BoxCP =
  struct

    include Apron_domain.MAKE (struct
                type t = Box.t
                let get_manager =  Box.manager_alloc ()
              end)

    let is_representable _ = Adcp_sig.Yes

    let is_small box : bool =
      let (_, _, max) = largest box in
      let dim = Mpqf.to_float max in
      (dim <= !Constant.precision)

    let split abs jacobian =
      let env = Abstract1.env abs in
      let (var, itv, size) = largest abs in
      let mid = mid_interval itv in
      let value = match Environment.typ_of_var env var with
        | Environment.INT -> scalar_plus_mpqf mid split_prec_mpqf
        | _ -> mid
      in
      (* var <= mid*)
      let expr =  Linexpr1.make env in
      Linexpr1.set_list expr [(Coeff.s_of_int (-1), var)] (Some (Coeff.Scalar (mid)));
      (* var >= value*)
      let expr' =  Linexpr1.make env in
      Linexpr1.set_list expr' [(Coeff.s_of_int 1, var)] (Some (Coeff.Scalar (Scalar.neg value)));
      split abs jacobian (expr,expr')

    let split_on _ _ _ = Pervasives.failwith "split_on: uninmplemented"
    let shrink _ _ = Pervasives.failwith "shrink: uninmplemented"

    let volume abs =
      let box = Abstract1.to_box man abs in
      let tab = box.Abstract1.interval_array in
      let vol = Array.fold_left (fun v itv -> Mpqf.mul v (diam_interval itv)) (Mpqf.of_int 1) tab in
      Mpqf.to_float vol
  end

(**
 * Module for the Octagon Abstract Domains for Constraint Programming.
 *)
module OctMinMinCP =
  struct

    include Apron_domain.MAKE (struct
                type t = Oct.t
                let get_manager =  Oct.manager_alloc ()
              end)

    let is_small octad =
      (*printf "oct = %a@." Abstract1.print octad;*)
      let env = Abstract1.env octad in
      let dim = Environment.size env in
      let coeff1 = Coeff.s_of_int 1 in
      let coeff_1 = Coeff.s_of_int (-1) in

      (* Compute the max and the min for the basis Bij *)
      let minmax_bij var_i var_j =
        let expr1 = Linexpr1.make env in
        Linexpr1.set_list expr1 [(coeff1, var_i) ; (coeff1, var_j)] None;
        let expr2 = Linexpr1.make env in
        Linexpr1.set_list expr2 [(coeff1, var_i) ; (coeff_1, var_j)] None;

        let expr1' = Linexpr1.make env in
        Linexpr1.set_list expr1' [(coeff_1, var_i) ; (coeff_1, var_j)] None;
        let expr2' = Linexpr1.make env in
        Linexpr1.set_list expr2' [(coeff_1, var_i) ; (coeff1, var_j)] None;

        (* Get the interval for the expression "vi + vj" and "vi -vj" *)
        let itv1 = Abstract1.bound_linexpr man octad expr1 in
        let diam1 = Scalar.of_mpqf (diam_interval itv1) in
        let itv2 = Abstract1.bound_linexpr man octad expr2 in
        let diam2 = Scalar.of_mpqf (diam_interval itv2) in

        let cond = (Scalar.cmp diam1 diam2 > 0) in
        let diam_max = if cond then (scalar_mul_sqrt2 diam1) else (scalar_mul_sqrt2 diam2) in
        let expr_max = if cond then expr1 else expr2 in
        let expr_max' = if cond then expr1' else expr2' in
        let itv_max = if cond then itv1 else itv2 in
        let diam_min = if cond then (scalar_mul_sqrt2 diam2) else (scalar_mul_sqrt2 diam1) in
        (*printf "      min = %f, max = %f@." (scalar_to_float diam_min) (scalar_to_float diam_max);*)
        (expr_max, expr_max', itv_max, diam_max, diam_min)
      in

      (* For a given i, compute the min of all the min for the basis Bij
       * and the corresopnding max.
       * min_{j \in \{i+1...n\}} (min Bij) *)
      let rec minmax_bi var_i j min max cst linexpr1 linexpr2 =
        if j >= dim then (linexpr1, linexpr2, cst, max, min)
        else
	        let var_j = Environment.var_of_dim env j in
          let (expr_max, expr_max', itv_max, diam_max, diam_min) = minmax_bij var_i var_j in
          if Scalar.cmp diam_min min < 0 then
            minmax_bi var_i (j+1) diam_min diam_max (mid_interval itv_max) expr_max expr_max'
          else
            minmax_bi var_i (j+1) min max cst linexpr1 linexpr2
      in

      (* Compute the min of all the min of the basis Bij and the corresponding max
       * min_{i \in \{1...n\}, j \in \{i+1...n\}} (min Bij) *)
      let rec minmax_b i min max cst linexpr1 linexpr2 =
        if i >= dim-1 then (linexpr1, linexpr2, cst, max, min)
        else
          let var_i = Environment.var_of_dim env i in
          let (linexpr1', linexpr2', cst', max', min') = minmax_bi var_i (i+1) min max cst linexpr1 linexpr2 in
          if Scalar.cmp min' min < 0 then minmax_b (i+1) min' max' cst' linexpr1' linexpr2'
          else minmax_b (i+1) min max cst linexpr1 linexpr2
      in

      let box = Abstract1.to_box man octad in
      let tab = box.Abstract1.interval_array in
      let (mmax, i_max, mmin, i_min) = minmax tab 1 (diam_interval tab.(0)) 0 (diam_interval tab.(0)) 0 in
      let mmax' = Scalar.of_mpqf mmax in
      let expr1 = Linexpr1.make env in
      Linexpr1.set_list expr1 [(coeff1, Environment.var_of_dim env i_max)] None;
      let expr2 = Linexpr1.make env in
      Linexpr1.set_list expr2 [(coeff_1, Environment.var_of_dim env i_max)] None;
      let mmin' = Scalar.of_mpqf mmin in
      let (linexpr1, linexpr2, cst, max, min) = minmax_b 0 mmin' mmax' (mid_interval tab.(i_max)) expr1 expr2 in
      let max = scalar_to_float max in
      (max <= !Constant.precision)

    let split octad =
      let env = Abstract1.env octad in
      let dim = Environment.size env in
      let coeff1 = Coeff.s_of_int 1 in
      let coeff_1 = Coeff.s_of_int (-1) in

      (* Compute the max and the min for the basis Bij *)
      let minmax_bij var_i var_j =
        let expr1 = Linexpr1.make env in
        Linexpr1.set_list expr1 [(coeff1, var_i) ; (coeff1, var_j)] None;
        let expr2 = Linexpr1.make env in
        Linexpr1.set_list expr2 [(coeff1, var_i) ; (coeff_1, var_j)] None;

        let expr1' = Linexpr1.make env in
        Linexpr1.set_list expr1' [(coeff_1, var_i) ; (coeff_1, var_j)] None;
        let expr2' = Linexpr1.make env in
        Linexpr1.set_list expr2' [(coeff_1, var_i) ; (coeff1, var_j)] None;

        (* Get the interval for the expression "vi + vj" and "vi -vj" *)
        let itv1 = Abstract1.bound_linexpr man octad expr1 in
        let diam1 = Scalar.of_mpqf (diam_interval itv1) in
        let itv2 = Abstract1.bound_linexpr man octad expr2 in
        let diam2 = Scalar.of_mpqf (diam_interval itv2) in

        let cond = (Scalar.cmp diam1 diam2 > 0) in
        let diam_max = if cond then (scalar_mul_sqrt2 diam1) else (scalar_mul_sqrt2 diam2) in
        let expr_max = if cond then expr1 else expr2 in
        let expr_max' = if cond then expr1' else expr2' in
        let itv_max = if cond then itv1 else itv2 in
        let diam_min = if cond then (scalar_mul_sqrt2 diam2) else (scalar_mul_sqrt2 diam1) in
        (*printf "      min = %f, max = %f@." (scalar_to_float diam_min) (scalar_to_float diam_max);*)
        (expr_max, expr_max', itv_max, diam_max, diam_min)
      in

      (* For a given i, compute the min of all the min for the basis Bij
       * and the corresopnding max.
       * min_{j \in \{i+1...n\}} (min Bij) *)
      let rec minmax_bi var_i j min max cst linexpr1 linexpr2 =
        if j >= dim then (linexpr1, linexpr2, cst, max, min)
        else
	        let var_j = Environment.var_of_dim env j in
          let (expr_max, expr_max', itv_max, diam_max, diam_min) = minmax_bij var_i var_j in
          if Scalar.cmp diam_min min < 0 then
            minmax_bi var_i (j+1) diam_min diam_max (mid_interval itv_max) expr_max expr_max'
          else
            minmax_bi var_i (j+1) min max cst linexpr1 linexpr2
      in
      let rec minmax_b i min max cst linexpr1 linexpr2 =
        if i >= dim-1 then (linexpr1, linexpr2, cst, max, min)
        else
          let var_i = Environment.var_of_dim env i in
          let (linexpr1', linexpr2', cst', max', min') = minmax_bi var_i (i+1) min max cst linexpr1 linexpr2 in
          if Scalar.cmp min' min < 0 then minmax_b (i+1) min' max' cst' linexpr1' linexpr2'
          else minmax_b (i+1) min max cst linexpr1 linexpr2
      in

      let box = Abstract1.to_box man octad in
      let tab = box.Abstract1.interval_array in
      let (mmax, i_max, mmin, i_min) = minmax tab 1 (diam_interval tab.(0)) 0 (diam_interval tab.(0)) 0 in
      let mmax' = Scalar.of_mpqf mmax in
      let expr1 = Linexpr1.make env in
      Linexpr1.set_list expr1 [(coeff1, Environment.var_of_dim env i_max)] None;
      let expr2 = Linexpr1.make env in
      Linexpr1.set_list expr2 [(coeff_1, Environment.var_of_dim env i_max)] None;
      let mmin' = Scalar.of_mpqf mmin in
      let (linexpr1, linexpr2, cst, max, min) = minmax_b 0 mmin' mmax' (mid_interval tab.(i_max)) expr1 expr2 in
      split octad [] (linexpr1,linexpr2)

    let volume box = 0.
  end

(**
 * Module for the Octagon Abstract Domains for Constraint Programming.
 *)
module OctMinMaxCP =
  struct

    include Apron_domain.MAKE (struct
                type t = Oct.t
                let get_manager =  Oct.manager_alloc ()
              end)

    let is_small octad =
      (*printf "oct = %a@." Abstract1.print octad;*)
      let env = Abstract1.env octad in
      let dim = Environment.size env in
      let coeff1 = Coeff.s_of_int 1 in
      let coeff_1 = Coeff.s_of_int (-1) in

      (* Compute the max for the basis Bij *)
      let max_bij var_i var_j =
        let expr1 = Linexpr1.make env in
        Linexpr1.set_list expr1 [(coeff1, var_i) ; (coeff1, var_j)] None;
        let expr2 = Linexpr1.make env in
        Linexpr1.set_list expr2 [(coeff1, var_i) ; (coeff_1, var_j)] None;

        let expr1' = Linexpr1.make env in
        Linexpr1.set_list expr1' [(coeff_1, var_i) ; (coeff_1, var_j)] None;
        let expr2' = Linexpr1.make env in
        Linexpr1.set_list expr2' [(coeff_1, var_i) ; (coeff1, var_j)] None;

        (* Get the interval for the expression "vi + vj" and "vi -vj" *)
        let itv1 = Abstract1.bound_linexpr man octad expr1 in
        let diam1 = Scalar.of_mpqf (diam_interval itv1) in
        let itv2 = Abstract1.bound_linexpr man octad expr2 in
        let diam2 = Scalar.of_mpqf (diam_interval itv2) in

        let cond = (Scalar.cmp diam1 diam2 > 0) in
        let diam_tmp = if cond then diam1 else diam2 in
        (*printf "%a ? %a : %a@." Scalar.print diam1 Scalar.print diam2 Scalar.print diam_tmp;*)
        let expr_tmp = if cond then expr1 else expr2 in
        let expr_tmp' = if cond then expr1' else expr2' in
        let itv_tmp = if cond then itv1 else itv2 in
        (expr_tmp, expr_tmp', itv_tmp, diam_tmp)
      in

      (* For a given i, compute the min of all the max for the basis Bij
       * min_{j \in \{i+1...n\}} (max Bij) *)
      let rec max_bi var_i j min_max cst linexpr1 linexpr2 =
        if j >= dim then
          (linexpr1, linexpr2, cst, min_max)
        else
          let var_j = Environment.var_of_dim env j in
          let (expr_tmp1, expr_tmp2, itv_tmp, diam_tmp) = max_bij var_i var_j in
          if Scalar.cmp diam_tmp min_max < 0 then
            max_bi var_i (j+1) diam_tmp (mid_interval itv_tmp) expr_tmp1 expr_tmp2
          else
            max_bi var_i (j+1) min_max cst linexpr1 linexpr2
      in

      (* Compute the min of all the max of the basis Bij
       * min_{i \in \{1...n\}, j \in \{i+1...n\}} (max Bij) *)
      let rec max i min_max cst linexpr1 linexpr2 =
        if i >= dim-1 then
          (linexpr1, linexpr2, cst, min_max)
        else
          (
            (*printf "[%a ; %a], %f" Linexpr1.print linexpr1 Linexpr1.print linexpr2 (scalar_to_float min_max);*)
            let var_i = Environment.var_of_dim env i in
            let (linexpr1', linexpr2', cst', min_max') = max_bi var_i (i+1) min_max cst linexpr1 linexpr2 in
            if Scalar.cmp min_max' min_max < 0 then
              (
                (* printf " > %f, [%a ; %a]@." (scalar_to_float min_max') Linexpr1.print linexpr1' Linexpr1.print linexpr2';*)
                max (i+1) min_max' cst' linexpr1' linexpr2'
              )
            else
              (
                (* printf " < %f, [%a ; %a]@." (scalar_to_float min_max') Linexpr1.print linexpr1' Linexpr1.print linexpr2';*)
                max (i+1) min_max cst linexpr1 linexpr2
              )
          )
      in

      (*printf "box = %a@." (print_array Interval.print) tab;*)
      let (var, itv, mmax) = largest octad in
      let mmax' = Scalar.of_mpqf mmax in
      let expr1 = Linexpr1.make env in
      Linexpr1.set_list expr1 [(coeff1, var)] None;
      let expr2 = Linexpr1.make env in
      Linexpr1.set_list expr2 [(coeff_1, var)] None;
      let (linexpr1, linexpr2, cst, min_max) = max 0 mmax' (mid_interval itv) expr1 expr2 in

      let sca_cst = scalar_plus_mpqf cst split_prec_mpqf in
      Linexpr1.set_cst linexpr1 (Coeff.Scalar (Scalar.neg sca_cst));
      Linexpr1.set_cst linexpr2 (Coeff.Scalar sca_cst);

      let max = scalar_to_float min_max in
      (*printf "max = %f@.split = [%a, %a]@." max Linexpr1.print linexpr1 Linexpr1.print linexpr2;*)
      (max <= !Constant.precision)

    let split octad jacobian =
      let env = Abstract1.env octad in
      let poly = to_poly octad env in
      split octad jacobian (get_expr (Polka.manager_alloc_strict()) poly)

    let split_on _ _ _ = Pervasives.failwith "split_on: uninmplemented"
    let shrink _ _ = Pervasives.failwith "shrink: uninmplemented"

    let volume box = 0.
  end

(**
 * Module for the Octagon Abstract Domains for Constraint Programming.
 *)
module OctBoxCP =
  struct

    include Apron_domain.MAKE (struct
                type t = Oct.t
                let get_manager =  Oct.manager_alloc ()
              end)

    let is_representable c =
      if (Csp.is_cons_linear c) then
        Adcp_sig.Yes
      else
        Adcp_sig.No

    let is_small oct =
      let (_, _,max) = largest oct in
      let dim = Mpqf.to_float max in
      (dim <= !Constant.precision)

    let split octad jacobian =
      let env = Abstract1.env octad in
      let (var, itv, size) = largest octad in
      let mid = mid_interval itv in
      let typ_var = Environment.typ_of_var env var in
      let value = if typ_var == Environment.INT then (scalar_plus_mpqf mid split_prec_mpqf) else mid in
      (* var <= mid*)
      let expr =  Linexpr1.make env in
      Linexpr1.set_list expr [(Coeff.s_of_int (-1), var)] (Some (Coeff.Scalar (mid)));
      (* var >= value*)
      let expr' =  Linexpr1.make env in
      Linexpr1.set_list expr' [(Coeff.s_of_int 1, var)] (Some (Coeff.Scalar (Scalar.neg value)));
      split octad jacobian (expr, expr')

    let split_on _ _ _ = Pervasives.failwith "split_on: uninmplemented"
    let shrink _ _ = Pervasives.failwith "shrink: uninmplemented"

    let volume box = 0.
  end

(**
 * Module for the Polyhedron Abstract Domains for Constraint Programming.
 *)
module PolyCP = struct
  include Apron_domain.MAKE (struct
              type t = Polka.strict Polka.t
              let get_manager = Polka.manager_alloc_strict()
            end)

  let is_small poly = is_small man poly

  let rec is_representable c =
    match c with
    | Csp.Cmp(_, _, _) as c ->
       if (Csp.is_cons_linear c) then
         Adcp_sig.Yes
       else
         Adcp_sig.No
    | Csp.And(e1, e2) -> Adcp_sig.and_ans (is_representable e1) (is_representable e2)
    | Csp.Or(e1, e2) -> Adcp_sig.No
    | Csp.Not(e) -> Adcp_sig.not_ans (is_representable e)

  let split poly jacobian =
    split poly jacobian (get_expr (Polka.manager_alloc_strict()) poly)

  let prune a b =
    let work acc a c =
      let neg_c = Linconsext.neg c in
      let a' = A.filter_lincons man a c
      and s = A.filter_lincons man a neg_c in
      if is_empty s then a,acc
      else a',(s::acc)
    in
    let _,pruned = Linconsext.array_fold
                     (fun (abs,acc) c ->
                       if Linconsext.get_typ c = Linconsext.EQ then
                         let c1,c2 = Linconsext.spliteq c in
                         let a',acc' = work acc a c1 in
                         work acc' a' c2
                       else work acc a c
                     ) (a,[]) (A.to_lincons_array man b)
    in pruned

  let prune = Some prune

  let volume box = 0.

  let split_on _ _ _ = Pervasives.failwith "split_on: uninmplemented"

  let shrink _ _ = Pervasives.failwith "shrink: uninmplemented"


end
