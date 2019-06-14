(** This file contains functions for the time step analyse. *)

open Analyzer_all

val nb_steps : int (* Number of steps. *)

val one_step : float (* Size of one step. *)

val count_time_strategy: float -> strategy_2 -> strategy_2 (** Count the number of instances solved at one step. *)

val count_time: instances_set_2 -> float -> instances_set_2 (** Process the time step analyse of an instances set at one step. *)

val exec_step: float -> float -> instances_set_2 -> instances_set_2 (** Process the time step analyse of an instances set for all steps. *)

val print_step: float * int -> unit
  
val print_steps_strategy: strategy_2 -> unit

val print_steps_instance: instances_set_2 -> unit

val print_steps: instances_set_2 list -> unit

val steps_to_time: float -> int -> string(** Return the list of steps. *)

val steps_to_string: (float * int) list -> string (** Return the json string from a the list of steps. *)
 
val strategy_to_json_string: string -> strategy_2 -> string (** Return the json string of the time step analyse from a strategy_2. *)

val instances_to_json_string: float -> int -> string -> instances_set_2 -> string (** Return the json string of the time step analyse from an instances_set_2. *)
  
val database_to_json_string: instances_set_2 list -> float -> int -> string (** Return the json string of the time step analyse from an instances_set_2 list. *)
  