(*This file contains function used by all analyses*)

open Absolute_analyzer

(*A second type for strategy*)
type strategy_2 = {
  string; (*The name of the solver*)
  string; (*The name of the strategy*)
  (string, instance) Hashtbl.t; (*The results of the strategy on all instances*)
  (float*int) list; (*Steps for time_step analyse*)
}

(*a second type for instances_set having the strategies of all solvers appended in the same list*)
type instances_set_2 = {
  string; (*The name of the problem*)
  string; (*The name of the instance set*) 
  int; (*The number of instances in this instance set*)
  strategy_2 list; (*The list of strategies*)
}

val timeout: float (*The value of the timeout*)

val add_key: string _ string list -> string list (*Add string in string list, called by get_keys*)

val get_keys: (string, instance) Hashtbl.t -> string list (*Get all the key from a Hashtbl*)

val remove_last_char: string -> string (*Remove the last char of a string*)

val float_option_to_string: float option -> string (*Convert a float option into a string*)

val convert_solver: solver strategy -> strategy_2 (*Convert a strategy into a strategy_2*)

val append_solvers: solver list -> strategy_2 list (*Return all strategies from a list of solver*)

val convert_instance: problem instances_set -> instances_set_2 (*Convert an instances_set into an instances_set_2*)

val append_problems: problem list -> instance_set_2 list (*Convert a list of problem into a list of instances_set_2*)