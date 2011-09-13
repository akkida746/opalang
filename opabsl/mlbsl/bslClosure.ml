(*
    Copyright © 2011 MLstate

    This file is part of OPA.

    OPA is free software: you can redistribute it and/or modify it under the
    terms of the GNU Affero General Public License, version 3, as published by
    the Free Software Foundation.

    OPA is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
    more details.

    You should have received a copy of the GNU Affero General Public License
    along with OPA. If not, see <http://www.gnu.org/licenses/>.
*)
##extern-type Closure.args = QmlClosureRuntime.AnyArray.t
##extern-type Closure.t = QmlClosureRuntime.t

##module Args
  ##register create \ `QmlClosureRuntime.AnyArray.create` : int -> Closure.args
  ##register length \ `QmlClosureRuntime.AnyArray.length` : Closure.args -> int
  ##register set \ `QmlClosureRuntime.AnyArray.set` : Closure.args, int, 'a -> void
  ##register get \ `QmlClosureRuntime.AnyArray.get` : Closure.args, int -> 'a
##endmodule

##register show \ `QmlClosureRuntime.show` : Closure.t -> string
##register create \ `QmlClosureRuntime.create` : 'impl, int, 'ident -> Closure.t
##register create_no_function \ `QmlClosureRuntime.create_no_function` : int, 'ident -> Closure.t
##register [opacapi] define_function \ `QmlClosureRuntime.define_function` : Closure.t, 'impl -> void
##register apply \ `QmlClosureRuntime.args_apply` : Closure.t, Closure.args -> 'a
##register is_empty \ `QmlClosureRuntime.is_empty` : 'closure -> bool
##register get_identifier \ `QmlClosureRuntime.get_identifier` : 'closure -> option('a)
##register set_identifier \ `QmlClosureRuntime.set_identifier` : Closure.t, 'a -> void
##register export \ `QmlClosureRuntime.export` : Closure.t -> 'a

(** Create an "anyarray" closure. These closures consider that the
    given native implementation is a function that takes an anyarray
    of size n rather than a function that take n arguments.
    see also [opavalue.opa (OpaValue.Closure)]
*)
##register create_anyarray \ `QmlClosureRuntime.create_anyarray` : 'impl, int, 'ident -> Closure.t

(* CLOSURE REGISTERING *)
(** Type of the information. *)
type t = {
  mutable local : QmlClosureRuntime.t;
  mutable distant : bool;
}

(** The association table. *)
let funtbl : (string, t) Hashtbl.t = Hashtbl.create 1024

let set str t = Hashtbl.add funtbl str t


##register on_distant : string -> bool
(** [on_distant "toto"] If returns true the "toto" function is
    present on the other side. *)
let on_distant str =
  Hashtbl.mem funtbl str && (Hashtbl.find funtbl str).distant

let fclosure_name = ServerLib.static_field_of_name "closure_name"

let make_closure_name name =
  ServerLib.make_record (ServerLib.add_field ServerLib.empty_record_constructor fclosure_name (ServerLib.wrap_string name))

##register [opacapi] create_and_register : 'impl, int, string, bool -> Closure.t
let create_and_register impl arity name distant =
  let ident = make_closure_name name in
  let closure = QmlClosureRuntime.create impl arity ident in
  set name { local = closure; distant = distant };
  closure

##register [opacapi] create_no_function_and_register : int, string, bool -> Closure.t
let create_no_function_and_register arity name distant =
  let ident = make_closure_name name in
  let closure = QmlClosureRuntime.create_no_function arity ident in
  set name { local = closure; distant = distant };
  closure

##register get_local : string -> option(Closure.t)
(** Get the local function, if returns [None] functions is not
    present locally. *)
let get_local str =
  try
    Some (Hashtbl.find funtbl str).local
  with Not_found -> None

##register set_distant_false : string -> void
(** If a client function get cleaned, set its distant property to
    false.  No need to create a container if the function was not
    already known. *)
let set_distant_false str =
  try
    (Hashtbl.find funtbl str).distant <- false;
  with Not_found ->
    ()

let replace_identifier key_ident ident =
  try
    let {distant; local=clos} = Hashtbl.find funtbl key_ident in
    assert (clos.QmlClosureRuntime.identifier <> None);
    clos.QmlClosureRuntime.identifier <- Some (Obj.repr (make_closure_name ident));
    Hashtbl.remove funtbl key_ident;
    Hashtbl.add funtbl ident {distant; local=clos};
   #<If:JS_RENAMING>
     Printf.printf "Closure update: %s to %s\n%!" key_ident ident;
   #<End>
  with Not_found ->
    #<If:JS_RENAMING>
      Printf.printf "Closure NO update: %s to %s\n%!" key_ident ident;
    #<End>;
    ()
