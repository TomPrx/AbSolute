(** This file parse the CSV file into structures and check the optimum obtained. *)

open Scanf

type optimum =
| Bounded of int * int (* [lb, ub] is the interval in which the optimum must be if it is satisfiable. *)
| Unsat

val no_lb: int 
val no_ub: int

(** Directory containing the optimum file. *)
val optimum_dir: string 
val optimum_file: string (** File containing the optimums. *) 

(** Solving information of an instance from a problems' set. *)
type instance = {
  problem: string;
  time: float option;
  bound: optimum;
  (* For nodes, solutions and fails, when the information is not available, we set it to 0. *)
  nodes: int;
  solutions: int;
  fails: int;
}

val empty_instance: instance

type strategy = {
  name: string;
  (* The name of the instance mapped to the time (if it did not timeout) and optimum found. *)
  all: (string, instance) Hashtbl.t;
  (* number of instances with at least one solution that is not proven optimal. *)
  feasible: int;
  (* number of instances with a proven optimum solution. *)
  optimum: int;
  (* number of instances proven unsatisfiable. *)
  unsat: int;
  (* difference between the lower bound obtained `lb` and the `best` known lower bound.
     Obtained with `(lb - best) / best`. *)
  delta_lb: float;
}

type solver = {
  name: string;
  strategies: strategy list;
}

type instances_set = {
  name: string;
  solvers: solver list;
  optimum: (string, optimum) Hashtbl.t
}

type problem = {
  name: string;
  instances_set: instances_set list;
}

type database = problem list

val check_solution: string -> optimum -> optimum -> unit (** Check the validity of one solution. *)

val check_solutions_validity: (string, optimum) Hashtbl.t -> strategy -> unit (** Check the validity of a strategy. *)
  
val compute_delta_lb: optimum -> int -> float (** Return the value of delta lb. *)

val process_instances: ('a, optimum) Hashtbl.t -> 'a -> instance -> strategy -> strategy (** Check if the instance is feasible, unsat, or optimum. *)

val process_strategy: (string, optimum) Hashtbl.t -> strategy -> strategy (** Process all instances of a strategy and fill delta_lb field. *)

val process_solver: (string, optimum) Hashtbl.t -> solver -> solver (** Process all strategies of a solver. *)

val process_instances_set: instances_set -> instances_set (** Process all solvers of an instances_set. *)
  
val process_problem: problem -> problem (** Process all instances_set of a problem. *)
  
val process_database: problem list -> problem list (** Process a list of problem. *)

val print_strategy: string -> string -> string -> strategy -> unit (** Print the results of a strategy. *) 

val print_solver: string -> string -> solver -> unit (** Print the results of a solver. *)

val print_instances_set: string -> instances_set -> unit (** Print the results of an instances_set. *)

val print_problem: problem -> unit (** Print the results of a problem. *)

val print_database: problem list -> unit (** Print the results of a list of problems. *)

val clean_split: char -> string -> string list (** Split results of a string with a given separtor. *)

(* The bound can be a single number, "unsat", "none" or an interval of the form "1..3", "..3" or "1..". *)
val parse_bound: float option -> string -> optimum (** Parse the bound optained from the CSV. *)

val content_of_dir: string -> string list (** Return the content of a directory into a list of string. *)

val remove_trailing_slash: string -> string (** Remove the slash from a string. *)

val concat_dir: string -> string -> string (** Concatenate the name of 2 directories. *)

val subdirs: string -> string list (** Return the subdirectories of a directory into a list of string. *)

val subfiles: string -> string list (** Return the subfiles of a directory into a list of string. *)
  
val file_to_lines: Scanning.in_channel -> string list (** Return the content of a file into a string list. *)

val is_digit: char -> bool (** Check if the char is a digit. *) 

val remove_trailing_letters: string -> string (** Remove the trailing letters from a string. *)

val parse_time: string -> float option (** Parse the time from the a CSV line. *)

val parse_csv_line: string list -> string -> instance (** Parse the results of an instance from a CSV line. *)

val parse_csv_header: Scanning.in_channel -> string list (** Parse the header of CSV. *)

val read_strategy: string -> string -> strategy (** Create a strategy from a CSV file. *)

val read_solver: string -> string -> solver (** Create a solver from a solver directory. *)

val parse_name_bound_line: string -> string * optimum (** Parse the name of the instance and the optimum from a CSV line. *)

val read_optimum_file: string -> (string, optimum) Hashtbl.t (** Create the optimum Hashtbl from the CSV optimum file. *)

val read_instances_set: string -> string -> instances_set (** Create an instances_set from an instances_set directory. *)

val read_problem: string -> string -> problem (** Create a problem from a problem directory. *)

val read_database: string -> problem list (** Create a list of problem from a database directory. *)
