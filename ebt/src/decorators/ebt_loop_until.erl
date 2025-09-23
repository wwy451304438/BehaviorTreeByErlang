%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 18:23
%%%-------------------------------------------------------------------
-module(ebt_loop_until).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(remain_loop_count, {?MODULE, '__remain_loop_count__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildId]}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?remain_loop_count) of
        0 ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?SUCCESS),
            ebt_behavior:leave(Rt1, Tree, Node);
        _ ->
            ebt_behavior:ahead(Rt, Tree, ChildId, NodeId)
    end.

on_aback(Rt, Tree, Node = #ebt_node{children = [ChildId]}) ->
    ChildResult = ebt_runtime:get_node_run_result(Rt, ChildId),
    Rt1 = case Node#ebt_node.decorator_when_child_end of
        true when ?is_running(ChildResult) ->
            ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, ChildResult);
        _ ->
            execute(Rt, Node)
    end,
    ebt_behavior:leave(Rt1, Tree, Node).

on_stop(Rt, Tree = #ebt_tree{id = TreeId},  #ebt_node{id = NodeId, children = [ChildId]}) ->
    Rt1 = ?__if(ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING, ebt_behavior:stop(Rt, Tree, ChildId), Rt),
    ebt_runtime:clr_node_run_result(Rt1, TreeId, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
execute(Rt, Node = #ebt_node{id = NodeId, children = [ChildId]}) ->
    LoopCount = ebt_runtime:get_property_as_operand(Rt, Node, count),
    ChildrenResult = ebt_runtime:get_node_run_result(Rt, ChildId),
    case ebt_runtime:get_property(Node, until) of
        true when ?is_success(ChildrenResult) ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?SUCCESS),
            ebt_runtime:set_status(Rt1, NodeId, ?remain_loop_count, 0);
        false when ?is_failure(ChildrenResult) ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE),
            ebt_runtime:set_status(Rt1, NodeId, ?remain_loop_count, 0);
        _ ->
            update_remain_loop_count(Rt, Node, LoopCount)
    end.

update_remain_loop_count(Rt, Node = #ebt_node{id = NodeId}, LoopCount) ->
    case ebt_runtime:get_status(Rt, Node, ?remain_loop_count, LoopCount) of
        RemainLoopCount when RemainLoopCount > 0 ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_loop_count, RemainLoopCount - 1),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?RUNNING);
        RemainLoopCount when RemainLoopCount < 0 ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?RUNNING);
        _ ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?SUCCESS)
    end.