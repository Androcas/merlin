open Std
open Misc

type directive = [
  | `B of string
  | `S of string
  | `CMI of string
  | `CMT of string
  | `PKG of string list
  | `EXT of string list
  | `FLG of string
]

type file = {
  project    : string option;
  path       : string;
  directives : directive list;
}

let parse_dot_merlin_file path : bool * file =
  let ic = open_in path in
  let acc = ref [] in
  let recurse = ref false in
  let proj = ref None in
  let tell l = acc := l :: !acc in
  try
    let rec aux () =
      let line = String.trim (input_line ic) in
      if line = "" then ()
      else if String.is_prefixed ~by:"B " line then
        tell (`B (String.drop 2 line))
      else if String.is_prefixed ~by:"S " line then
        tell (`S (String.drop 2 line))
      else if String.is_prefixed ~by:"SRC " line then
        tell (`S (String.drop 4 line))
      else if String.is_prefixed ~by:"CMI " line then
        tell (`CMI (String.drop 4 line))
      else if String.is_prefixed ~by:"CMT " line then
        tell (`CMT (String.drop 4 line))
      else if String.is_prefixed ~by:"PKG " line then
        tell (`PKG (rev_split_words (String.drop 4 line)))
      else if String.is_prefixed ~by:"EXT " line then
        tell (`EXT (rev_split_words (String.drop 4 line)))
      else if String.is_prefixed ~by:"FLG " line then
        tell (`FLG (String.drop 4 line))
      else if String.is_prefixed ~by:"REC" line then
        recurse := true
      else if String.is_prefixed ~by:"PRJ " line then
        proj := Some (String.trim (String.drop 4 line))
      else if String.is_prefixed ~by:"PRJ" line then
        proj := Some ""
      else if String.is_prefixed ~by:"#" line then
        ()
      else
        Logger.info Logger.Section.project_load ~title:".merlin"
          (sprintf "unexpected directive \"%s\"" line) ;
      aux ()
    in
    aux ()
  with
  | End_of_file ->
    close_in_noerr ic;
    !recurse, {project = !proj; path; directives = !acc}
  | exn ->
    close_in_noerr ic;
    raise exn

let rec read ~path =
  let recurse, dot_merlin = parse_dot_merlin_file path in
  let next = if recurse
    then lazy (find ~path:(Filename.dirname (Filename.dirname path)))
    else lazy List.Lazy.Nil
  in
  List.Lazy.Cons (dot_merlin, next)

and find ~path =
  match find_in_parent_directories path ~what:".merlin" with
  | Some path -> read path
  | None -> List.Lazy.Nil

let rec project_name = function
  | List.Lazy.Cons (({project = Some ""; path = name} | {project = Some name}), _) ->
    Some name
  | List.Lazy.Cons ({path}, lazy List.Lazy.Nil) -> Some path
  | List.Lazy.Cons (_, lazy tail) -> project_name tail
  | List.Lazy.Nil -> None

type config =
  {
    dot_merlins : string list;
    build_path  : string list;
    source_path : string list;
    cmi_path    : string list;
    cmt_path    : string list;
    packages    : string list;
    flags       : string list list;
    extensions  : string list;
  }

let parse_dot_merlin {path; directives} config =
  let cwd = Filename.dirname path in
  let expand path acc =
    let path = expand_directory Config.standard_library path in
    let path = canonicalize_filename ~cwd path in
    expand_glob ~filter:Sys.is_directory path acc
  in
  List.fold_left ~init:{config with dot_merlins = path :: config.dot_merlins}
  ~f:(fun config ->
    function
    | `B path -> {config with build_path = expand path config.build_path}
    | `S path -> {config with source_path = expand path config.source_path}
    | `CMI path -> {config with cmi_path = expand path config.cmi_path}
    | `CMT path -> {config with cmt_path = expand path config.cmt_path}
    | `PKG pkgs -> {config with packages = pkgs @ config.packages}
    | `EXT exts ->
      {config with extensions = exts @ config.extensions}
    | `FLG flags ->
      let flags = List.rev (rev_split_words flags) in
      {config with flags = flags :: config.flags}
  ) directives

let empty_config = {
  build_path  = [];
  source_path = [];
  cmi_path    = [];
  cmt_path    = [];
  packages    = [];
  dot_merlins = [];
  extensions  = [];
  flags       = [];
}

let rec parse ?(config=empty_config) =
  function
  | List.Lazy.Cons (dot_merlin, lazy tail) ->
    parse ~config:(parse_dot_merlin dot_merlin config) tail
  | List.Lazy.Nil ->
    let prepare path = List.rev (List.filter_dup path) in
    {
      dot_merlins = config.dot_merlins;
      build_path  = prepare config.build_path;
      source_path = prepare config.source_path;
      cmi_path    = prepare config.cmi_path;
      cmt_path    = prepare config.cmt_path;
      packages    = prepare config.packages;
      extensions  = prepare config.extensions;
      flags       = prepare config.flags;
    }

let path_of_packages packages =
  let packages =  packages in
  let f pkg =
    try Either.R (Findlib.package_deep_ancestors [] [pkg])
    with exn ->
      Logger.infof Logger.Section.project_load ~title:"findlib"
        (fun fmt (exn, pkg) -> Format.fprintf fmt "%s: %s" pkg (Printexc.to_string exn))
        (exn, pkg) ;
      Either.L (pkg, exn)
  in
  let packages = List.map ~f packages in
  let failures, packages = Either.split packages in
  let packages = List.filter_dup (List.concat packages) in
  let path = List.map ~f:Findlib.package_directory packages in
  let failures = match failures with
    | [] -> `Ok
    | ls -> `Failures ls
  in
  failures, path
