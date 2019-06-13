(* This file contains function for the instance inclusion analyse*)

open Absolute_analyzer
open Analyzer_all

(* Constains the results of an instance inclusion analyse *)
type instances_inclusion = {
  strategy; (* The first strategy compared *)
  strategy; (* The second strategy compared *)
  string list; (* The list of instances solved by the strategies *)
  string list; (* The list of instances solved by none of the strategies *)
  string list; (* The list of instances solved only by the first strategy *)
  string list; (* The list of instances solved only by the second strategy *)
}

val check_inclusion: strategy strategy instances_inclusion string -> instances_inclusion (* Process the instance inclusion analyse of one instance *)

val compute_set: strategy strategy -> instances_inclusion (* Process the instance inclusion analyse of all instances*)
