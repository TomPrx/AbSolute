(* This file contains the structures and the functions to process all different analyses *)

open Absolute_analyzer
open Instance_inclusion
open Cactus_plot
open Topen Absolute_analyzer
open Instance_inclusion
open Cactus_plot
open Time_step
open Analyzer_all

(* Unused *)
type comp = {
  delta_feas : float;
  delta_opt : float;
  delta_unsat : float;
  delta_lb : float;
}

(* This structure contains the results of all the analyses performed between a pair a strategies *)
type comp_solver_strategy = {
  solver; (* The first solver*)
  solver; (* The second solver *)
  strategy; (* The first strategy *)
  strategy; (* The second strategy *)
  instances_inclusion; (* The results of the instances inclusion analyse *)
}

(* This structure contains the results of one strategy compared to a list of strategies*)
type comp_strategies = {
  solver;
  solver;
  strategy;
  comp_solver_strategy list;
}

(* This structure contains the results of the analyses between a pair of solvers *)
type comp_solver = {
  solver;
  solver;
  comp_strategies list;
}

(* This structure contains the results of the analyses between a solver and a list of solvers *)
type comp_solver_to_others = {
  solver : solver;
  others : solver list;
  comp_solver : comp_solver list;
}

(* This structure contains the results of the analyses for one instances set *)
type comp_instance = {
  instances_set;
  comp_solver_to_others list
}

(* This strucutre contains the results of the analyses for one problem *)
type comp_problem = {
  problem;
  comp_instance list;
}

(* Unused *)
type split_solvers = {
  solver list;
  solver list;
}

(* Process the analyses between 2 strategies *)
val compare_solver_strategy: solver solver strategy strategy -> comp_solver_strategy

(* Process the analyses between one strategy and a list of strategies *)
val compare_strategies: solver other strategy -> comp_strategies

(* Process the analyses between a pair of solvers *)
val compare_solver: solver solver) -> comp_solver

(* Process the analyses between one solver and a list of solvers *)
val compare_solver_to_others: solver list solver -> comp_solver_to_others

(* Process the analyses for one instance set *)
val compare_instances_set: instances_set -> comp_instance

(* Process the analyses for one problem *)
val compare_problem: problem -> comp_problem

(* Duplicated code *)
val remove_last_char: string -> string

(* Return the name of an analyse *)
val json_name: int -> string  

(* Return the json string of one analyse *)
val to_json_solver_strategy: int problem instances_set string comp_solver_strategy -> string 

(* Return the json string of one analyse from one strategy and a list of strategies*)
val to_json_strategies: int problem instance string comp_strategies -> string 

(* Return the json string of one analyse from a pair of solver*)
val to_json_solver: int problem instance string comp_solver -> string 

(* Return the json string of one analyse from one solver and a list of solvers*)
val to_json_solvers: int problem instance string comp_solvers ->

(* Return the json string of one analyse from an instances_set*)
val to_json_instances_set: int problem string comp_instances ->

(* Return the json string of one analyse from a problem*)
val to_json_problem: int string comp_problem -> string 

(* Return the json string of all analyses from a list of comp_problem *)
val to_json_comp_database: comp_problem list -> string 

(* Process the analyses and return the corresponding json string *)
val to_json_database: problem list -> string 

