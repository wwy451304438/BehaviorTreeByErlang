%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 9:17
%%%-------------------------------------------------------------------
-module(ebt_end).
-author("wwy").

-behaviour(ebt_behavior).

-include("ebt.hrl").

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt = #ebt_rt{tree_path = TreePath}, Tree = #ebt_tree{id = TreeId}, Node) ->
    Result = ebt_runtime:get_property_as_operand(Rt, Node, result),
    Rt1 = ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, Result),
    case ?is_running(Result) orelse ?is_invalid(Result) of
        true ->
            ebt_behavior:leave(Rt1, Tree, Node);
        false when TreePath == [] ->
            ebt_runtime:clr_from(Rt1);
        false ->
            case ebt_runtime:get_property(Node, 'quit') of
                true  ->
                    ebt_behavior:quit(ebt_runtime:clr_from(Rt1));
                false ->
                    ebt_behavior:quit(ebt_runtime:clr_from(Rt1, TreeId))
            end
    end.

on_aback(_Rt, _Tree, _Node) ->
    erlang:error(not_implemented).

on_stop(Rt, Tree, Node) ->
    ebt_runtime:clr_node_run_result(Rt, Tree#ebt_tree.id, Node#ebt_node.id).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------