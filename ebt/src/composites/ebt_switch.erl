%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 14:22
%%%-------------------------------------------------------------------
-module(ebt_switch).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(remain_child, {?MODULE, '__remain_child__'}).
-define(child_result, {?MODULE, '__child_result__'}).
-define(last_select, {?MODULE, '__last_select__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{children = [ChildId | _]}) ->
    Rt1 = ebt_runtime:set_status(Rt, Node#ebt_node.id, ?remain_child, Node#ebt_node.children),
    ebt_behavior:ahead(Rt1, Tree, ChildId, Node#ebt_node.id).

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    [PreChildId | RemainChild] = ebt_runtime:get_status(Rt, NodeId, ?remain_child),
    PreChildResult = ebt_runtime:get_node_run_result(Rt, PreChildId),
    case PreChildResult of
        _ when PreChildResult == ?RUNNING; PreChildResult == ?SUCCESS ->
            LastSelect = ebt_runtime:get_status(Rt, NodeId, ?last_select),
            Rt1 = ?__if(
                LastSelect /= PreChildId andalso LastSelect /= ?__nil,
                ebt_behavior:stop(Rt, Tree, LastSelect),
                Rt
            ),
            Rt2 = ebt_runtime:set_node_run_result(Rt1, NodeId, PreChildResult),
            Rt3 = ebt_runtime:set_status(Rt2, NodeId, ?last_select, PreChildId),
            ebt_behavior:leave(Rt3, Tree, Node);
        _ when RemainChild == [] ->
            LastSelect = ebt_runtime:get_status(Rt, NodeId, ?last_select),
            Rt1 = ?__if(LastSelect /= ?__nil, ebt_behavior:stop(Rt, Tree, LastSelect), Rt),
            Rt2 = ebt_runtime:set_node_run_result(Rt1, NodeId, ?FAILURE),
            Rt3 = ebt_runtime:clr_status(Rt2, NodeId),
            ebt_behavior:leave(Rt3, Tree, Node);
        _ ->
            [NextChildId | _] = RemainChild,
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_child, RemainChild),
            ebt_behavior:ahead(Rt1, Tree, NextChildId, NodeId)
    end.

on_stop(Rt, Tree = #ebt_tree{id = TreeId}, #ebt_node{id = NodeId, children = ChildIds}) ->
    RunningChild = get_running_node(Rt, TreeId, ChildIds),
    Rt1 = ebt_behavior:stop(Rt, Tree, RunningChild),
    Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
    ebt_runtime:clr_node_run_result(Rt2, TreeId, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
get_node_result(Rt, TreeId, ChildIds) ->
    IsRunning = lists:any(
        fun(ChildId) ->
            ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING
        end, ChildIds),
    ?__if(IsRunning, ?RUNNING, ?SUCCESS).

get_running_node(Rt, TreeId, ChildIds) ->
    lists:foldl(
        fun(ChildId, AccChild) ->
            ?__if(
                ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING,
                [ChildId | AccChild],
                AccChild
            )
        end, [], ChildIds).