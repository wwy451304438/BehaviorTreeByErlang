%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 17:58
%%%-------------------------------------------------------------------
-module(ebt_log).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{children = [ChildId]}) ->
    ebt_behavior:ahead(Rt, Tree, ChildId, Node#ebt_node.id).

on_aback(Rt, Tree, Node = #ebt_node{children = [ChildId]}) ->
    ChildResult = ebt_runtime:get_node_run_result(Rt, ChildId),
    case Node#ebt_node.decorator_when_child_end of
        true when ?is_running(ChildResult) ->
            skip;
        _ ->
            ebt_runtime:log_msg("--------message:~ts", [ebt_runtime:get_property_as_operand(Rt, Node, msg)])
    end,
    Rt1 = ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, ChildResult),
    ebt_behavior:leave(Rt1, Tree, Node).

on_stop(Rt, Tree = #ebt_tree{id = TreeId},  #ebt_node{id = NodeId, children = [ChildId]}) ->
    Rt1 = ?__if(ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING, ebt_behavior:stop(Rt, Tree, ChildId), Rt),
    ebt_runtime:clr_node_run_result(Rt1, TreeId, NodeId).

%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------