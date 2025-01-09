open Linol_eio
open Libsail
open Libsail.Frontend
open Lsp.Types
open Jsonrpc2
open Parse_ast
module IO = Linol_eio.IO_eio

type state_after_processing = unit

let process_some_input_file (_file_contents : string) : state_after_processing = ()

module Log = struct
  let file = open_out "/tmp/yacht_lsp.log"

  let log str =
    output_string file (str ^ "\n");
    flush file

  let debug fmt = Format.kasprintf log fmt
end

let new_r (row_s : int) (col_s : int) (row_e : int) (col_e : int) =
  Range.create ~end_:(Position.create ~character:col_e ~line:row_e) ~start:(Position.create ~character:col_s ~line:row_s)

let new_l (row_s : int) (col_s : int) (row_e : int) (col_e : int) (uri : string) =
  Location.create ~range:(new_r row_s col_s row_e col_e) ~uri:(DocumentUri.of_path uri)

let sail_dir =
  let open Filename in
  concat (concat (concat (dirname Sys.executable_name) parent_dir_name) "share") "sail"

let register_default_target () = Target.register ~name:"default" ~supports_abstract_types:true Target.empty_action

let default_target = register_default_target ()

let get_ordered_files project_files () =
  let t = Profile.start () in
  let defs =
    List.map
      (fun project_file ->
        let root_directory = Filename.dirname project_file in
        let contents = Util.file_to_string project_file in
        Project.mk_root root_directory :: Initial_check.parse_project ~filename:project_file ~contents ()
      )
      project_files
    |> List.concat
  in
  let variables = ref Util.StringMap.empty in
  let proj = Project.initialize_project_structure ~variables defs in
  let mod_ids = Project.all_modules proj in

  Profile.finish "parsing project" t;
  let env = Type_check.initial_env_with_modules proj in
  let res = Frontend.load_modules ~target:default_target sail_dir [] env proj mod_ids in
  res

let get_mod_filename path =
  let defs =
    List.map
      (fun project_file ->
        let root_directory = Filename.dirname project_file in
        let contents = Util.file_to_string project_file in
        Project.mk_root root_directory :: Initial_check.parse_project ~filename:project_file ~contents ()
      )
      ["mod.sail_project"]
    |> List.concat
  in
  let variables = ref Util.StringMap.empty in
  let proj = Project.initialize_project_structure ~variables defs in
  let open Project in
  let mod_ids = module_order proj in
  let result = ref path in
  for i = 0 to List.length mod_ids - 1 do
    let mod_id = List.nth mod_ids i in
    let files = module_files proj mod_id in
    (* List.find_opt (fun (filename, a) -> true) files) *)
    for j = 0 to List.length files - 1 do
      let filename = List.nth files j |> fst in
      let root_directory = Sys.getcwd () in
      let full_path = Filename.concat root_directory (Filename.basename filename) in
      Log.debug "get_mod_filename: %s" full_path;
      if full_path = path then result := filename
    done
  done;
  !result

class lsp_server =
  object (self)
    inherit Linol_eio.Jsonrpc2.server

    (* one env per document *)
    val buffers : (Lsp.Types.DocumentUri.t, state_after_processing) Hashtbl.t = Hashtbl.create 32

    method spawn_query_handler f = Linol_eio.spawn f

    (* We define here a helper method that will:
       - process a document
       - store the state resulting from the processing
       - return the diagnostics from the new state
    *)
    method private _on_doc ~(notify_back : Linol_eio.Jsonrpc2.notify_back) (uri : Lsp.Types.DocumentUri.t)
        (contents : string) =
      self#_on_doc_handler ~notify_back uri contents;
      ()

    method private _on_doc_handler ~(notify_back : Linol_eio.Jsonrpc2.notify_back) (uri : Lsp.Types.DocumentUri.t)
        (contents : string) =
      Log.debug "_on_doc_handler";
      let new_state = process_some_input_file "" in
      Hashtbl.replace buffers uri new_state;

      let path = Lsp.Uri.to_path uri in
      let mod_path = get_mod_filename path in
      Log.debug "path: [%s] mod_path: [%s]" path mod_path;
      Log.debug "contents: [%s]" contents;
      Sail_file.editor_reset_file ~contents:(Util.file_to_string path) mod_path;
      let t = Printf.sprintf "%f" (Unix.time ()) in
      Log.debug "before diags %s" t;
      let diag, ast =
        try
          (* handle type check *)
          let ctx, ast, env, effect_info =
            (* If there are no provided project files, we concatenate all
               the free file arguments into one big blob like before *)
            get_ordered_files ["mod.sail_project"] ()
            (* load_files ~target:tgt sail_dir !options Type_check.initial_env frees *)
          in
          let res_ast = ast in
          (* let ast =
               let opt_instantiations : (Ast.kind_aux -> Ast.typ_arg) Ast_util.Bindings.t ref =
                 ref Ast_util.Bindings.empty
               in
               Frontend.instantiate_abstract_types (Some tgt) !opt_instantiations ast
             in
             let ast, env = Frontend.initial_rewrite effect_info env ast in
             let ast, env =
               let opt_splice : string list ref = ref [] in
               match !opt_splice with [] -> (ast, env) | files -> Splice.splice_files ctx ast (List.rev files)
             in
             let effect_info = Effects.infer_side_effects (Target.asserts_termination tgt) ast in

             (* Don't show warnings during re-writing for now *)
             Reporting.suppressed_warning_info ();
             Reporting.opt_warnings := false;

             Target.run_pre_rewrites_hook tgt ast effect_info env;
             let _ =
               (* let ctx, ast, effect_info, env = *)
               Rewrites.rewrite ctx effect_info env (Target.rewrites tgt) ast
             in *)
          (None, Some res_ast)
          (* List.fold_left (fun "" e -> "") effect_info "" *)
        with Libsail.Reporting.Fatal_error e ->
          Log.debug "get_ordered_files failed";
          (Some (Reporting.dest_err e), None)
      in
      let diags =
        [
          Diagnostic.create ~message:t ~severity:DiagnosticSeverity.Information ~range:(new_r 0 0 0 0) ();
          Diagnostic.create
            ~message:("文件读取结果:\n" ^ Util.file_to_string path)
            ~severity:DiagnosticSeverity.Information ~range:(new_r 0 0 0 0) ();
        ]
      in
      let diags =
        match diag with
        | Some (err_type, hint, loc, msg) ->
            Log.debug "_on_doc_handler diag msg %s" msg;
            diags
            @ [
                Diagnostic.create
                  ~message:
                    (Printf.sprintf "%s %s %s" err_type msg
                       (match loc with Reporting.Loc loc -> Reporting.loc_to_string loc | _ -> "")
                    )
                  ~range:
                    ( match loc with
                    | Reporting.Pos { pos_fname; pos_lnum; pos_bol; pos_cnum } ->
                        let row = pos_lnum - 1 in
                        new_r row pos_bol row pos_bol
                    | Reporting.Loc loc -> (
                        match loc with
                        (* | Unique of int * l *)
                        (* | Generated of l *)
                        (* | Hint (hint, l1, l2) -> new_r 0 0 0 0 *)
                        | Range (p1, p2) -> new_r (p1.pos_lnum - 1) p1.pos_bol (p2.pos_lnum - 1) p2.pos_bol
                        | Unknown | _ -> new_r 0 9 0 13
                      )
                    )
                  ();
              ]
        | _ -> diags
      in
      Log.debug "发送开始";
      notify_back#send_diagnostic diags;
      Log.debug "发送成功"
    (* match !last_notify_back with Some n -> n#send_diagnostic diags *)

    (* We now override the [on_notify_doc_did_open] method that will be called
       by the server each time a new document is opened. *)
    method on_notif_doc_did_open ~notify_back d ~content : unit Linol_eio.t =
      (* TODO: do type check *)
      Log.debug "on_notif_doc_did_open";
      self#_on_doc ~notify_back d.uri content

    (* Similarly, we also override the [on_notify_doc_did_change] method that will be called
       by the server each time a new document is opened. *)
    method on_notif_doc_did_change ~notify_back d _c ~old_content:_old ~new_content =
      (* TODO: do type check *)
      IO.return ()

    (* On document closes, we remove the state associated to the file from the global
       hashtable state, to avoid leaking memory. *)
    method on_notif_doc_did_close ~notify_back:_ d : unit Linol_eio.t =
      Hashtbl.remove buffers d.uri;
      IO.return ()

    method on_notif_doc_did_save ~(notify_back : notify_back) (_params : DidSaveTextDocumentParams.t) : unit IO.t =
      Log.debug "on_notif_doc_did_save";
      let d = _params.textDocument in
      let new_content = match _params.text with Some t -> t | _ -> "" in
      self#_on_doc ~notify_back d.uri new_content

    method! config_hover : [ `Bool of bool | `HoverOptions of HoverOptions.t ] option = Option.some @@ `Bool true

    (** Called when the user hovers on some identifier in the document *)
    method! on_req_hover ~notify_back:(_ : notify_back) ~id:_ ~uri:_ ~pos:_ ~workDoneToken:_ (_ : doc_state)
        : Hover.t option IO.t =
      let content = MarkupContent.create ~kind:MarkupKind.Markdown ~value:"# 大标题" in
      IO.return @@ Some (Hover.create ~contents:(`MarkupContent content) ~range:(new_r 0 1 0 2) ())

    method! config_definition : [ `Bool of bool | `DefinitionOptions of DefinitionOptions.t ] option =
      Option.some @@ `Bool true

    (** Called when the user wants to jump-to-definition  *)
    method! on_req_definition ~notify_back:(_ : notify_back) ~id:_ ~uri ~pos:_ ~workDoneToken:_ ~partialResultToken:_
        (_ : doc_state) : Locations.t option IO.t =
      let loc = Location.create ~range:(new_r 0 0 0 0) ~uri in
      let locs = [loc] in
      IO.return @@ Option.some @@ `Location locs
  end

(* Main code
   This is the code that creates an instance of the lsp server class
   and runs it as a task. *)
let run () =
  Libsail.Util.opt_colors := false;

  Eio_main.run @@ fun env ->
  let s = new lsp_server in
  let server = Linol_eio.Jsonrpc2.create_stdio ~env s in
  let task () =
    let shutdown () = s#get_status = `ReceivedExit in
    Linol_eio.Jsonrpc2.run ~shutdown server
  in
  match task () with
  | () -> ()
  | exception e ->
      let e = Printexc.to_string e in
      Printf.eprintf "error: %s\n%!" e;
      exit 1

(* Finally, we actually run the server *)
let () = run ()
