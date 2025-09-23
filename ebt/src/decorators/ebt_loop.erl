%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 18:08
%%%-------------------------------------------------------------------
-module(ebt_loop).
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
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE),
            ebt_behavior:leave(Rt1, Tree, Node);
        _ ->
            ebt_behavior:ahead(Rt, Tree, ChildId, NodeId)
    end.

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildId]}) ->
    ChildResult = ebt_runtime:get_node_run_result(Rt, ChildId),
    Rt1 = case Node#ebt_node.decorator_when_child_end of
        true when ?is_running(ChildResult) ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ChildResult);
        _ ->
            execute(Rt, Tree, Node)
    end,
    ebt_behavior:leave(Rt1, Tree, Node).

on_stop(Rt, Tree = #ebt_tree{id = TreeId},  #ebt_node{id = NodeId, children = [ChildId]}) ->
    Rt1 = ?__if(ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING, ebt_behavior:stop(Rt, Tree, ChildId), Rt),
    ebt_runtime:clr_node_run_result(Rt1, TreeId, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
execute(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    LoopCount = ebt_runtime:get_property_as_operand(Rt, Node, count),
    WithInFrame = ebt_runtime:get_property(Node, within_frame),
    case true of
        _ when LoopCount < 0, WithInFrame ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_loop_count, 0),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?INVALID);
        _ when WithInFrame ->
            loop_execute(Rt, Tree, Node, LoopCount - 1);
        _ ->
            update_remain_loop_count(Rt, NodeId, LoopCount)
    end.

loop_execute(Rt, _Tree, Node, LoopCount) when LoopCount =< 0 ->
    Rt1 = ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, ?SUCCESS),
    ebt_runtime:set_status(Rt1, Node#ebt_node.id, ?remain_loop_count, 0);
loop_execute(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildrenId]}, LoopCount) ->
    Rt1 = ebt_behavior:ahead(Rt, Tree, ChildrenId, NodeId),
    case ebt_runtime:get_node_run_result(Rt1, ChildrenId) of
        ?FAILURE ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE),
            ebt_runtime:set_status(Rt1, Node#ebt_node.id, ?remain_loop_count, 0);
        ?RUNNING when Node#ebt_node.decorator_when_child_end ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?INVALID),
            ebt_runtime:set_status(Rt1, Node#ebt_node.id, ?remain_loop_count, 0);
        _ ->
            loop_execute(Rt1, Tree, Node, LoopCount - 1)
    end.

update_remain_loop_count(Rt, NodeId, LoopCount) ->
    case ebt_runtime:get_status(Rt, NodeId, ?remain_loop_count, LoopCount) of
        RemainLoopCount when RemainLoopCount > 0 ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?RUNNING),
            ebt_runtime:set_status(Rt1, NodeId, ?remain_loop_count, RemainLoopCount - 1);
        RemainLoopCount when RemainLoopCount < 0 ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?RUNNING);
        _ ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE)
    end.