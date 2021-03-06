%% -----------------------------------------------------------------------------
%%
%% plsql_parser_format_dbss.erl: PL/SQL - creating a DBSS specific XML version
%%                                        of the PL/SQL script.
%%
%% Copyright (c) 2018-20 Konnexions GmbH.  All Rights Reserved.
%%
%% -----------------------------------------------------------------------------

-module(plsql_parser_format_dbss).

-export([finalize/2, fold/5, init/1]).

-define(NODEBUG, true).
-define(
  TABULATOR,
  case LOpts#lopts.indent_with of
    tab -> ?CHAR_TAB;

    _ ->
      case LOpts#lopts.indent_space of
        2 -> "  ";
        3 -> "   ";
        4 -> "    ";
        5 -> "     ";
        6 -> "      ";
        7 -> "       ";
        8 -> "        ";
        _ -> " "
      end
  end
).

-include("plsql_parser_format_dbss.hrl").

-type layout_opts() :: #lopts{}.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Setting up optional parameters.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec init(LOpts :: list() | map()) -> LOpts :: layout_opts().
init(LOpts) when is_map(LOpts) ->
  ?D("Start~n LOpts: ~p~n", [LOpts]),
  RT = init(maps:to_list(LOpts)),
  ?D("End~n LOpts: ~p~n", [RT]),
  RT;

init(LOpts) when is_list(LOpts) ->
  ?D("Start~n LOpts: ~p~n", [LOpts]),
  RT = process_lopts(#lopts{}, LOpts),
  ?D("End~n LOpts: ~p~n", [RT]),
  RT.


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Postprocessing of the resulting SQL statement.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec finalize(Params :: any(), Ctx :: string() | tuple()) -> Ctx :: binary() | tuple().
finalize(_Params, Ctx) when is_list(Ctx) ->
  ?D("Start~n Params: ~p~n CtxOut: ~p~n", [_Params, Ctx]),
  list_to_binary(string:trim(Ctx)).


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Layout methods for processing the various parser subtrees
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% apiGroupAnnotation
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, _FunState, Ctx, #{apiGroupAnnotation := PTree}, {apiGroupAnnotation, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<ApiGroupPrivilege>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<ApiGroup>",
            maps:get(apiGroup@, PTree),
            "</ApiGroup>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "</ApiGroupPrivilege>",
            ?CHAR_NEWLINE
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% apiHiddenAnnotation
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(
  LOpts,
  _FunState,
  Ctx,
  #{apiHiddenAnnotation := PTree},
  {apiHiddenAnnotation, Step} = _FoldState
) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<ApiHidden>",
            maps:get(apiHidden@, PTree),
            "</ApiHidden>",
            ?CHAR_NEWLINE
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% columnRef
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, #{columnRef := PTree}, {columnRef, Step} = _FoldState)
when is_list(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        Ctx ++ case is_last_tag_open(Ctx) of
          true -> PTree;
          _ -> []
        end;

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% columnRefCommaList@
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, _PTree, {columnRefCommaList@, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, _PTree, _FoldState),
  RT =
    case Step of
      start ->
        Ctx ++ case is_last_tag_open(Ctx) of
          true -> "(";
          _ -> []
        end;

      _ ->
        Ctx ++ case is_last_tag_open(Ctx) of
          true -> ")";
          _ -> []
        end
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% dataSourceCommaList@
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, _PTree, {dataSourceCommaList@, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, _PTree, _FoldState),
  RT =
    case Step of
      start -> Ctx ++ "(";
      _ -> Ctx ++ ")"
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% dataType
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, FunState, Ctx, #{dataType := PTree}, {dataType, Step} = _FoldState) when is_map(PTree) ->
  ?CUSTOM_INIT(FunState, Ctx, PTree, _FoldState),
  {Stmnt, _, _} = plsql_parser_fold:get_stmnt_clause_curr(FunState),
  Type = maps:get(type@, PTree),
  RT =
    case {Step, Stmnt} of
      {start, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<DataType>",
            Type,
            case Type of
              "INTERVAL DAY" ->
                lists:append(
                  [
                    case maps:is_key(dayPrecision@, PTree) of
                      true -> lists:append(["(", maps:get(dayPrecision@, PTree), ")"]);
                      _ -> []
                    end,
                    " to second",
                    case maps:is_key(secondPrecision@, PTree) of
                      true -> lists:append(["(", maps:get(secondPrecision@, PTree), ")"]);
                      _ -> []
                    end
                  ]
                );

              "INTERVAL YEAR" ->
                lists:append(
                  [
                    case maps:is_key(precision@, PTree) of
                      true -> lists:append(["(", maps:get(precision@, PTree), ")"]);
                      _ -> []
                    end,
                    " to month"
                  ]
                );

              "TIMESTAMP" ->
                lists:append(
                  [
                    case maps:is_key(precision@, PTree) of
                      true -> lists:append(["(", maps:get(precision@, PTree), ")"]);
                      _ -> []
                    end,
                    case maps:is_key(timeZone@, PTree) of
                      true ->
                        lists:append(
                          [
                            " with",
                            case maps:is_key(local@, PTree) of
                              true -> " local";
                              _ -> []
                            end,
                            " time zone"
                          ]
                        );

                      _ -> []
                    end
                  ]
                );

              _ ->
                lists:append(
                  [
                    case maps:is_key(precision@, PTree) of
                      true ->
                        lists:append(
                          [
                            "(",
                            maps:get(precision@, PTree),
                            case maps:is_key(scale@, PTree) of
                              true -> lists:append([",", maps:get(scale@, PTree), ")"]);
                              _ -> ")"
                            end
                          ]
                        );

                      _ -> []
                    end,
                    case maps:is_key(size@, PTree) of
                      true ->
                        lists:append(
                          [
                            "(",
                            maps:get(size@, PTree),
                            case maps:is_key(sizeType@, PTree) of
                              true -> lists:append([" ", maps:get(sizeType@, PTree), ")"]);
                              _ -> ")"
                            end
                          ]
                        );

                      _ -> []
                    end,
                    case maps:is_key(attribute@, PTree) of
                      true -> maps:get(attribute@, PTree);
                      _ -> []
                    end
                  ]
                )
            end,
            "</DataType>",
            ?CHAR_NEWLINE
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% default
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, FunState, Ctx, #{default := PTree}, {default, Step} = _FoldState) when is_map(PTree) ->
  ?CUSTOM_INIT(FunState, Ctx, PTree, _FoldState),
  {Stmnt, _, _} = plsql_parser_fold:get_stmnt_clause_curr(FunState),
  RT =
    case {Step, Stmnt} of
      {start, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        lists:append(
          [Ctx, ?TABULATOR, ?TABULATOR, ?TABULATOR, ?TABULATOR, "<DefaultValue>", ?CHAR_NEWLINE]
        );

      {_, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        lists:append(
          [Ctx, ?TABULATOR, ?TABULATOR, ?TABULATOR, ?TABULATOR, "</DefaultValue>", ?CHAR_NEWLINE]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% defaultValue@_@
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, FunState, Ctx, #{defaultValue@_@ := PTree}, {defaultValue@_@, Step} = _FoldState) ->
  ?CUSTOM_INIT(FunState, Ctx, PTree, _FoldState),
  {Stmnt, _, _} = plsql_parser_fold:get_stmnt_clause_curr(FunState),
  Expression = maps:get(expression, PTree),
  Type =
    case is_map(Expression) andalso maps:is_key(string, Expression) of
      true -> "String";
      _ -> "Expression"
    end,
  RT =
    case {Step, Stmnt} of
      {start, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        lists:append(
          [Ctx, ?TABULATOR, ?TABULATOR, ?TABULATOR, ?TABULATOR, ?TABULATOR, "<", Type, ">"]
        );

      {_, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        lists:append([Ctx, "</", Type, ">", ?CHAR_NEWLINE]);

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% expression
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, FunState, Ctx, #{expression := PTree}, {expression, Step} = _FoldState)
when is_atom(PTree) ->
  ?CUSTOM_INIT(FunState, Ctx, PTree, _FoldState),
  {Stmnt, _, _} = plsql_parser_fold:get_stmnt_clause_curr(FunState),
  RT =
    case {Step, Stmnt} of
      {start, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        lists:append([Ctx, atom_to_list(PTree)]);

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

fold(_LOpts, FunState, Ctx, #{expression := PTree}, {expression, Step} = _FoldState)
when is_map(PTree) ->
  ?CUSTOM_INIT(FunState, Ctx, PTree, _FoldState),
  {Stmnt, _, _} = plsql_parser_fold:get_stmnt_clause_curr(FunState),
  Operator =
    case maps:is_key(operator@, PTree) of
      true -> maps:get(operator@, PTree);
      _ -> []
    end,
  RT =
    case {Step, Stmnt} of
      {start, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        Ctx ++ case Operator of
          'NOT' -> "not ";
          '(' -> "(";
          _ -> []
        end;

      {_, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        Ctx ++ case Operator of
          '(' -> ")";
          _ -> []
        end;

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% functionArg
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, #{functionArg := PTree}, {functionArg, Step} = _FoldState)
when map_size(PTree) == 2 ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start -> lists:append([Ctx, maps:get(name@, PTree), "=>"]);
      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% functionArgCommaList@
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, _PTree, {functionArgCommaList@, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, _PTree, _FoldState),
  RT =
    case Step of
      start -> Ctx ++ "(";
      _ -> Ctx ++ ")"
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% functionRef
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, #{functionRef := PTree}, {functionRef, Step} = _FoldState)
when is_map(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start -> Ctx ++ maps:get(name@, PTree);
      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% literal
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, FunState, Ctx, #{literal := PTree}, {literal, Step} = _FoldState) when is_list(PTree) ->
  ?CUSTOM_INIT(FunState, Ctx, PTree, _FoldState),
  {Stmnt, _, _} = plsql_parser_fold:get_stmnt_clause_curr(FunState),
  RT =
    case {Step, Stmnt} of
      {start, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        Ctx ++ PTree;

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% objectPrivilegeAnnotation
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(
  LOpts,
  _FunState,
  Ctx,
  #{objectPrivilegeAnnotation := PTree},
  {objectPrivilegeAnnotation, Step} = _FoldState
) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<ApiGroupPrivilege>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Privilege>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Type>",
            string:uppercase(maps:get(privilegeType@, PTree)),
            "</Type>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Object>",
            maps:get(object@, PTree),
            "</Object>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "</Privilege>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "</ApiGroupPrivilege>",
            ?CHAR_NEWLINE
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% operator
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, PTree, {operator, Step} = _FoldState) when is_atom(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start -> lists:append([Ctx, " ", atom_to_list(PTree), " "]);
      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% packageFunctionDeclaration
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(
  LOpts,
  _FunState,
  Ctx,
  #{packageFunctionDeclaration := PTree},
  {packageFunctionDeclaration, Step} = _FoldState
) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        Ctx ++ case maps:is_key(man_page@, PTree) of
          true ->
            lists:append(
              [
                ?TABULATOR,
                ?TABULATOR,
                ?TABULATOR,
                "<ManPage><![CDATA[",
                ?CHAR_NEWLINE,
                maps:get(man_page@, PTree),
                ?CHAR_NEWLINE,
                ?TABULATOR,
                ?TABULATOR,
                ?TABULATOR,
                "]]></ManPage>",
                ?CHAR_NEWLINE
              ]
            );

          _ -> []
        end;

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% packageProcedureDeclaration
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(
  LOpts,
  _FunState,
  Ctx,
  #{packageProcedureDeclaration := PTree},
  {packageProcedureDeclaration, Step} = _FoldState
) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        Ctx ++ case maps:is_key(man_page@, PTree) of
          true ->
            lists:append(
              [
                ?TABULATOR,
                ?TABULATOR,
                ?TABULATOR,
                "<ManPage><![CDATA[",
                ?CHAR_NEWLINE,
                maps:get(man_page@, PTree),
                ?CHAR_NEWLINE,
                ?TABULATOR,
                ?TABULATOR,
                ?TABULATOR,
                "]]></ManPage>",
                ?CHAR_NEWLINE
              ]
            );

          _ -> []
        end;

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% packageItemConditional
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(
  LOpts,
  _FunState,
  Ctx,
  #{packageItemConditional := PTree},
  {packageItemConditional, Step} = _FoldState
)
when is_map(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  PackageItem@ = maps:get(packageItem@, PTree),
  Type = maps:get(type, PackageItem@),
  RT =
    case {Step, Type} of
      {_, TypeArg} when TypeArg =/= "Function", TypeArg =/= "Procedure" -> Ctx;

      {start, _} ->
        Name =
          case Type of
            "Function" ->
              PackageFunctionDeclaration = maps:get(packageFunctionDeclaration, PackageItem@),
              FunctionHeading@ = maps:get(functionHeading@, PackageFunctionDeclaration),
              FunctionHeading = maps:get(functionHeading, FunctionHeading@),
              maps:get(name@, FunctionHeading);

            _ ->
              PackageProcedureDeclaration = maps:get(packageProcedureDeclaration, PackageItem@),
              ProcedureHeading@ = maps:get(procedureHeading@, PackageProcedureDeclaration),
              ProcedureHeading = maps:get(procedureHeading, ProcedureHeading@),
              maps:get(name@, ProcedureHeading)
          end,
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            "<",
            Type,
            ">",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Name>",
            Name,
            "</Name>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Condition>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<",
            case {maps:get(start@, PTree), maps:is_key(end@, PTree) == true} of
              {"$IF", false} -> "If";
              {"$IF", true} -> "IfEnd";
              {"$ELSIF", false} -> "ElsIf";
              {"$ELSIF", true} -> "ElsIfEnd";
              _ -> "Else"
            end,
            ">",
            case maps:get(start@, PTree) of
              "$ELSE" ->
                lists:append(
                  [
                    "</Else>",
                    ?CHAR_NEWLINE,
                    ?TABULATOR,
                    ?TABULATOR,
                    ?TABULATOR,
                    "</Condition>",
                    ?CHAR_NEWLINE
                  ]
                );

              _ -> []
            end
          ]
        );

      {_, _} -> lists:append([Ctx, ?TABULATOR, ?TABULATOR, "</", Type, ">", ?CHAR_NEWLINE])
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% packageItemSimple
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, _FunState, Ctx, #{packageItemSimple := PTree}, {packageItemSimple, Step} = _FoldState)
when is_map(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  PackageItem@ = maps:get(packageItem@, PTree),
  Type = maps:get(type, PackageItem@),
  RT =
    case {Step, Type} of
      {_, TypeArg} when TypeArg =/= "Function", TypeArg =/= "Procedure" -> Ctx;

      {start, _} ->
        Name =
          case Type of
            "Function" ->
              PackageFunctionDeclaration = maps:get(packageFunctionDeclaration, PackageItem@),
              FunctionHeading@ = maps:get(functionHeading@, PackageFunctionDeclaration),
              FunctionHeading = maps:get(functionHeading, FunctionHeading@),
              maps:get(name@, FunctionHeading);

            _ ->
              PackageProcedureDeclaration = maps:get(packageProcedureDeclaration, PackageItem@),
              ProcedureHeading@ = maps:get(procedureHeading@, PackageProcedureDeclaration),
              ProcedureHeading = maps:get(procedureHeading, ProcedureHeading@),
              maps:get(name@, ProcedureHeading)
          end,
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            "<FunctionProcedure>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            "<",
            Type,
            ">",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Name>",
            Name,
            "</Name>",
            ?CHAR_NEWLINE
          ]
        );

      {_, _} ->
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            "</",
            Type,
            ">",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            "</FunctionProcedure>",
            ?CHAR_NEWLINE
          ]
        )
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parameterDeclaration
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(
  LOpts,
  _FunState,
  Ctx,
  #{parameterDeclaration := PTree},
  {parameterDeclaration, Step} = _FoldState
)
when is_map(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        Mode =
          case maps:is_key(mode@, PTree) of
            true -> maps:get(mode@, PTree);
            _ -> "IN"
          end,
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Name>",
            maps:get(name@, PTree),
            "</Name>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Mode>",
            Mode,
            case maps:is_key(nocopy@, PTree) of
              true -> " " ++ maps:get(nocopy@, PTree);
              _ -> []
            end,
            "</Mode>",
            ?CHAR_NEWLINE
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parameterDeclarationCommaList
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, _FunState, Ctx, PTree, {parameterDeclarationCommaList, Step, _Pos} = _FoldState)
when is_map(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append([Ctx, ?TABULATOR, ?TABULATOR, ?TABULATOR, "<Parameter>", ?CHAR_NEWLINE]);

      _ -> lists:append([Ctx, ?TABULATOR, ?TABULATOR, ?TABULATOR, "</Parameter>", ?CHAR_NEWLINE])
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parameterRef
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, #{parameterRef := PTree}, {parameterRef, Step} = _FoldState)
when is_list(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start -> Ctx ++ PTree;
      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

fold(_LOpts, _FunState, Ctx, #{parameterRef := PTree}, {parameterRef, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append(
          [
            Ctx,
            maps:get(parameterLeft@, PTree),
            case maps:is_key(indicator@, PTree) of
              true -> " indicator ";
              _ -> " "
            end,
            maps:get(parameterRight@, PTree)
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% pipelinedClause
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, _FunState, Ctx, _PTree, {pipelinedClause, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, _PTree, _FoldState),
  RT =
    case Step of
      start ->
        Ctx
        ++
        lists:append(
          [?TABULATOR, ?TABULATOR, ?TABULATOR, "<Pipelined>TRUE</Pipelined>", ?CHAR_NEWLINE]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plsqlPackageSource
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, _FunState, Ctx, #{plsqlPackageSource := PTree}, {plsqlPackageSource, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            "<Name>",
            maps:get(packageNameStart@, PTree),
            "</Name>",
            ?CHAR_NEWLINE,
            case maps:is_key(man_page@, PTree) of
              true ->
                lists:append(
                  [
                    ?TABULATOR,
                    "<ManPage><![CDATA[",
                    ?CHAR_NEWLINE,
                    maps:get(man_page@, PTree),
                    ?CHAR_NEWLINE,
                    ?TABULATOR,
                    "]]></ManPage>",
                    ?CHAR_NEWLINE
                  ]
                );

              _ -> []
            end
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plsqlUnit
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, _PTree, {plsqlUnit, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, _PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append(
          [
            Ctx,
            "<?xml version='1.0' encoding='UTF-8'?>",
            ?CHAR_NEWLINE,
            "<Package xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:noNamespaceSchemaLocation='../../priv/dbss.xsd'>",
            ?CHAR_NEWLINE
          ]
        );

      _ -> lists:append([Ctx, "</Package>", ?CHAR_NEWLINE])
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% return
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, _FunState, Ctx, _PTree, {return, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, Ctx, _PTree, _FoldState),
  RT =
    case Step of
      start -> lists:append([Ctx, ?TABULATOR, ?TABULATOR, ?TABULATOR, "<Return>", ?CHAR_NEWLINE]);
      _ -> lists:append([Ctx, ?TABULATOR, ?TABULATOR, ?TABULATOR, "</Return>", ?CHAR_NEWLINE])
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% systemPrivilegeAnnotation
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(
  LOpts,
  _FunState,
  Ctx,
  #{systemPrivilegeAnnotation := PTree},
  {systemPrivilegeAnnotation, Step} = _FoldState
) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start ->
        lists:append(
          [
            Ctx,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<ApiGroupPrivilege>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Privilege>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "<Type>",
            string:uppercase(maps:get(privilegeType@, PTree)),
            "</Type>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "</Privilege>",
            ?CHAR_NEWLINE,
            ?TABULATOR,
            ?TABULATOR,
            ?TABULATOR,
            "</ApiGroupPrivilege>",
            ?CHAR_NEWLINE
          ]
        );

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% thenExpression@_@
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(LOpts, _FunState, Ctx, PTree, {thenExpression@_@, Step} = _FoldState) when is_map(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  RT =
    case Step of
      start -> Ctx;

      _ ->
        LastTag = string:find(Ctx, "<", trailing),
        Match =
          case string:prefix(LastTag, "<ElsIf>") of
            nomatch ->
              case string:prefix(LastTag, "<ElsIfEnd>") of
                nomatch ->
                  case string:prefix(LastTag, "<If>") of
                    nomatch ->
                      case string:prefix(LastTag, "<IfEnd>") of
                        nomatch -> false;
                        _ -> "</IfEnd>"
                      end;

                    _ -> "</If>"
                  end;

                _ -> "</ElsIfEnd>"
              end;

            _ -> "</ElsIf>"
          end,
        lists:append(
          [
            Ctx,
            case Match of
              false -> [];

              _ ->
                lists:append(
                  [
                    Match,
                    ?CHAR_NEWLINE,
                    ?TABULATOR,
                    ?TABULATOR,
                    ?TABULATOR,
                    "</Condition>",
                    ?CHAR_NEWLINE
                  ]
                )
            end
          ]
        )
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% unaryAddOrSubtract
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, FunState, Ctx, #{unaryAddOrSubtract := PTree}, {unaryAddOrSubtract, Step} = _FoldState)
when is_list(PTree) ->
  ?CUSTOM_INIT(_FunState, Ctx, PTree, _FoldState),
  {Stmnt, _, _} = plsql_parser_fold:get_stmnt_clause_curr(FunState),
  RT =
    case {Step, Stmnt} of
      {start, StmntX}
      when StmntX == none;
           StmntX == packageFunctionDeclaration;
           StmntX == packageProcedureDeclaration ->
        Ctx ++ PTree;

      _ -> Ctx
    end,
  ?CUSTOM_RESULT(RT);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NO ACTION.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, Ctx, _PTree, {Rule, _Step, _Pos})
when Rule == accessorCommaList;
     Rule == columnRefCommaList;
     Rule == dataSourceCommaList;
     Rule == fieldDefinitionCommaList;
     Rule == functionArgCommaList;
     Rule == packageFunctionDeclarationAttributeList;
     Rule == packageItemList;
     Rule == plsqlPackageSourceAttributeList;
     Rule == privilegeAnnotationList;
     Rule == restrictReferencesList ->
  Ctx;

fold(_LOpts, _FunState, Ctx, _PTree, {Rule, _Step})
when Rule == accessibleByClause;
     Rule == accessor;
     Rule == assocArrayTypeDef;
     Rule == collectionTypeDefinition;
     Rule == columnRefCommaList;
     Rule == constantDeclaration;
     Rule == constantName;
     Rule == createPackage;
     Rule == dataSource;
     Rule == dataSourceCommaList;
     Rule == dataTypeIndex;
     Rule == dataTypeTable;
     Rule == defaultCollationClause;
     Rule == exceptionDeclaration;
     Rule == expression;
     Rule == fieldDefinition;
     Rule == functionAnnotation;
     Rule == functionArg;
     Rule == functionArgCommaList;
     Rule == functionHeading;
     Rule == invokerRightsClause;
     Rule == notNull;
     Rule == packageFunctionDeclaration@_@;
     Rule == packageFunctionDeclarationAttribute;
     Rule == packageItemList@_@;
     Rule == packageProcedureDeclaration@_@;
     Rule == parallelEnabledClause;
     Rule == parameterDeclarationCommaList;
     Rule == parameterDeclarationCommaList@;
     Rule == pragmaDeclaration;
     Rule == pragmaParameter;
     Rule == plsqlPackageSourceAttribute;
     Rule == plsqlUnit;
     Rule == plsqlUnitList;
     Rule == privilegeAnnotationList@_@;
     Rule == procedureAnnotation;
     Rule == procedureHeading;
     Rule == recordTypeDefinition;
     Rule == recordTypeName;
     Rule == refCursorTypeDefinition;
     Rule == restrictReferences;
     Rule == restrictReferencesList@_@;
     Rule == resultCacheClause;
     Rule == scalarExpression;
     Rule == scalarSubExpression;
     Rule == sharingClause;
     Rule == sqlplusCommand;
     Rule == streamingClause;
     Rule == streamingClauseExpression@_@;
     Rule == subtypeDefinition;
     Rule == subtypeName;
     Rule == typeName;
     Rule == variableDeclaration;
     Rule == varraySize;
     Rule == varrayType;
     Rule == varrayTypeDef ->
  Ctx;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% UNSUPPORTED
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fold(_LOpts, _FunState, _Ctx, PTree, {Rule, Step, Pos} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, _Ctx, PTree, _FoldState),
  throw(
    {
      lists:append(
        [
          "[",
          ?MODULE_STRING,
          ":",
          atom_to_list(?FUNCTION_NAME),
          "] error parser subtree not supported [rule=",
          atom_to_list(Rule),
          " / step=",
          atom_to_list(Step),
          " / pos=",
          atom_to_list(Pos),
          "]"
        ]
      ),
      PTree
    }
  );

fold(_LOpts, _FunState, _Ctx, PTree, {Rule, Step} = _FoldState) ->
  ?CUSTOM_INIT(_FunState, _Ctx, PTree, _FoldState),
  throw(
    {
      lists:append(
        [
          "[",
          ?MODULE_STRING,
          ":",
          atom_to_list(?FUNCTION_NAME),
          "] error parser subtree not supported [rule=",
          atom_to_list(Rule),
          " / step=",
          atom_to_list(Step),
          "]"
        ]
      ),
      PTree
    }
  ).


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helper functions
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Determine if the last element is open.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_last_tag_open(Xml) ->
  case string:find(Xml, "<", trailing) of
    nomatch -> false;

    Tag ->
      case string:prefix(Tag, "</") of
        nomatch -> true;
        _ -> false
      end
  end.


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Validation and storage of input parameters.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
process_lopts(LOpts, []) ->
  ?D("Start~n LOpts: ~p~n", [LOpts]),
  LOpts;

process_lopts(LOpts, [{indent_space = Parameter, Value} | Tail] = _Params) ->
  ?D("Start~n LOpts: ~p~n Params: ~p~n", [LOpts, _Params]),
  case Value of
    Valid when is_integer(Valid), Valid >= 0, Valid =< 8 -> ok;

    _ ->
      io:format(
        user,
        "~n" ++ ?MODULE_STRING ++ " : invalid parameter value : parameter: ~p value: ~p~n",
        [Parameter, Value]
      ),
      throw(invalid_parameter_value)
  end,
  process_lopts(LOpts#lopts{indent_space = Value}, Tail);

process_lopts(LOpts, [{indent_with = Parameter, Value} | Tail] = _Params) ->
  ?D("Start~n LOpts: ~p~n Params: ~p~n", [LOpts, _Params]),
  case Value of
    Valid when Valid == space; Valid == tab -> ok;

    _ ->
      io:format(
        user,
        "~n" ++ ?MODULE_STRING ++ " : invalid parameter value : parameter: ~p value: ~p~n",
        [Parameter, Value]
      ),
      throw(invalid_parameter_value)
  end,
  process_lopts(LOpts#lopts{indent_with = Value}, Tail);

process_lopts(_LOpts, [{Parameter, Value} | _Tail] = _Params) ->
  ?D("Start~n LOpts: ~p~n Params: ~p~n", [_LOpts, _Params]),
  io:format(
    user,
    "~n" ++ ?MODULE_STRING ++ " : invalid parameter : parameter: ~p value: ~p~n",
    [Parameter, Value]
  ),
  throw(invalid_parameter).
