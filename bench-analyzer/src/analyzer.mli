(** This file contains the structures and the functions to process all different analyses. *)

open Absolute_analyzer
open Instance_inclusion

(** Results of all the analyses performed between a pair a strategies. *)
type comp_solver_strategy = {
  solver: solver; (** First solve. *)
  other: solver; (** Second solver. *)
  solver_strategy : strategy; (** First strategy. *)
  other_strategy : strategy; (** Second strategy. *)
  instances_inclusion : instances_inclusion; (** Results of the instances inclusion analyse. *)
}

(** Results of one strategy compared to a list of strategie. *)
type comp_strategies = {
  solver : solver;
  other : solver;
  solver_strategy : strategy;
  comp_solver_strategies : comp_solver_strategy list;
}

(** Results of the analyses between a pair of solvers. *)
type comp_solver = {
  solver : solver;
  other : solver;
  comp_strategies : comp_strategies list;
}

(** Results of the analyses between a solver and a list of solvers. *)
type comp_solver_to_others = {
  solver : solver;
  others : solver list;
  comp_solver : comp_solver list;
}

(** Results of the analyses for one instances set. *)
type comp_instance = {
  instance : instances_set;
  comp_solvers : comp_solver_to_others list
}

(** Results of the analyses for one problem. *)
type comp_problem = {
  problem : problem;
  comp_instances : comp_instance list;
}

(** Process the analyses between 2 strategies. *)
val compare_solver_strategy: solver -> solver -> strategy -> strategy -> comp_solver_strategy

(** Process the analyses between one strategy and a list of strategies. *)
val compare_strategies: solver -> solver -> strategy -> comp_strategies

(** Process the analyses between a pair of solvers. *)
val compare_solver: solver -> solver -> comp_solver

(** Process the analyses between one solver and a list of solvers. *)
val compare_solver_to_others: solver list -> solver -> comp_solver_to_others

(** Process the analyses for one instance set. *)
val compare_instances_set: instances_set -> comp_instance

(** Process the analyses for one problem. *)
val compare_problem: problem -> comp_problem

(** Duplicated code. *)
val remove_last_char: string -> string

(** Return the name of an analyse. *)
val json_name: int -> string  

(** Return the json string of one analyse. *)
val to_json_solver_strategy: int -> problem -> instances_set -> string -> comp_solver_strategy -> string 

(** Return the json string of one analyse from one strategy and a list of strategie. *)
val to_json_strategies: int -> problem -> instances_set -> string -> comp_strategies -> string 

(** Return the json string of one analyse from a pair of solve. *)
val to_json_solver: int -> problem -> instances_set -> string -> comp_solver -> string 

(** Return the json string of one analyse from one solver and a list of solver. *)
val to_json_solvers: int -> problem -> instances_set -> string -> comp_solver_to_others -> string

(** Return the json string of one analyse from an instances_se. *)
val to_json_instances_set: int -> problem -> string -> comp_instance -> string 

(** Return the json string of one analyse from a proble. *)
val to_json_problem: int -> string -> comp_problem -> string 

(** Return the json string of all analyses from a list of comp_problem. *)
val to_json_comp_database: comp_problem list -> string 

(** Process the analyses and return the corresponding json string. *)
val to_json_database: problem list -> string 

