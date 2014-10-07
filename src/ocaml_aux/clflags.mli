(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 2005 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* $Id: clflags.mli 12800 2012-07-30 18:59:07Z doligez $ *)

(* Command-line parameters *)

type set = {
  include_dirs                 : string list ref;
  std_include                  : string list ref;
  mutable fast                 : bool;
  mutable classic              : bool;
  mutable principal            : bool;
  mutable real_paths           : bool;
  mutable timed_logs           : bool;
  mutable recursive_types      : bool;
  mutable strict_sequence      : bool;
  mutable applicative_functors : bool;
  mutable unsafe_string        : bool;
  mutable nopervasives         : bool;
  mutable strict_formats       : bool;
  mutable open_modules         : string list;
  mutable auto_load            : bool;
}

(* Manage set of flag *)
val initial : set

val fresh : unit -> set
val copy : set -> set

(* Current state *)
val set : set ref

val include_dirs         : unit -> string list
val no_std_include       : unit -> bool
val fast                 : unit -> bool
val classic              : unit -> bool
val principal            : unit -> bool
val real_paths           : unit -> bool
val timed_logs           : unit -> bool
val recursive_types      : unit -> bool
val strict_sequence      : unit -> bool
val applicative_functors : unit -> bool
val unsafe_string        : unit -> bool
val nopervasives         : unit -> bool
val strict_formats       : unit -> bool
val open_modules         : unit -> string list

(* Enable autoloading of packages based on findlib *)
val auto_load            : unit -> bool

(* Dummy values *)
val annotations          : unit -> bool
val binary_annotations   : unit -> bool
val print_types          : unit -> bool
val native_code          : unit -> bool
val dont_write_files     : unit -> bool
val error_size           : unit -> int (* max size of module related errors *)
val keep_locs            : unit -> bool
val transparent_modules  : unit -> bool

(* Compute arguments specification *)
val arg_spec : set -> (string * Arg.spec * string) list
