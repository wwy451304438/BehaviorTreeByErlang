%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 16:32
%%%-------------------------------------------------------------------
-module(ebt_count).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(interrupt, {?MODULE, '__interrupt__'}).
-define(remain_count, {?MODULE, '__remain_count__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    case Node of
        #ebt_node{interrupt = [InterruptId]} ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?interrupt, true),
            ebt_behavior:ahead(Rt1, Tree, InterruptId, NodeId);
        _ ->
            run_child(Rt, Tree, Node)
    end.

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildId]}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?interrupt, false) of
        true ->
            [InterruptId] = Node#ebt_node.interrupt,
            case ebt_runtime:get_node_run_result(Rt, InterruptId) of
                ?SUCCESS ->
                    Rt1 = ebt_runtime:clr_status(Rt, NodeId),
                    run_child(Rt1, Tree, Node);
                _ ->
                    run_child(Rt, Tree, Node)
            end;
        false ->
            ChildResult = ebt_runtime:get_node_run_result(Rt, ChildId),
            case Node#ebt_node.decorator_when_child_end of
                true when not ?run_finish(ChildResult) ->
                    Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ChildResult),
                    ebt_behavior:leave(Rt1, Tree, Node);
                _ ->
                    update_remain_count(Rt, Node, ChildResult)
            end

    end.

on_stop(Rt, Tree = #ebt_tree{id = TreeId}, #ebt_node{id = NodeId, children = [ChildId]}) ->
    Rt1 = ?__if(ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING, ebt_behavior:stop(Rt, Tree, ChildId), Rt),
    ebt_runtime:clr_node_run_result(Rt1, TreeId, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
run_child(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildrenId]}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?remain_count) of
        RemainCount when is_integer(RemainCount), RemainCount == 0 ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE),
            ebt_behavior:leave(Rt1, Tree, Node);
        _ ->
            Rt1 = ebt_runtime:clr_status(Rt, NodeId, ?interrupt),
            ebt_behavior:ahead(Rt1, Tree, ChildrenId, NodeId)
    end.


update_remain_count(Rt, Node = #ebt_node{id = NodeId}, ChildrenResult) ->
    case ebt_runtime:get_status(Rt, NodeId, ?remain_count) of
        ?__nil ->
            Count = ebt_runtime:get_property_as_operand(Rt, Node, count),
            Count1 = ?__if(Count =< 0, Count, Count - 1),
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_count, Count1),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ChildrenResult);
        RemainCount when RemainCount < 0 ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ChildrenResult);
        RemainCount when RemainCount > 0 ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_count, RemainCount - 1),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ChildrenResult);
        _ ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE)
    end.