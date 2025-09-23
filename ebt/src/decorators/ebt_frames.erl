%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 17:48
%%%-------------------------------------------------------------------
-module(ebt_frames).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(remain_frames, {?MODULE, '__remain_frames__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildId]}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?remain_frames) of
        RemainFrames when is_integer(RemainFrames), RemainFrames =< 0 ->
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
            update_remain_frames(Rt, Node)
    end,
    ebt_behavior:leave(Rt1, Tree, Node).

on_stop(Rt, Tree = #ebt_tree{id = TreeId},  #ebt_node{id = NodeId, children = [ChildId]}) ->
    Rt1 = ?__if(ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING, ebt_behavior:stop(Rt, Tree, ChildId), Rt),
    ebt_runtime:clr_node_run_result(Rt1, TreeId, NodeId).

%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
update_remain_frames(Rt, Node = #ebt_node{id = NodeId}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?remain_frames) of
        ?__nil ->
            Frames = ebt_runtime:get_property_as_operand(Rt, Node, frames),
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_frames, Frames - 1),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?RUNNING);
        RemainFrames when RemainFrames > 0->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_frames, RemainFrames - 1),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?RUNNING);
        _ ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE)
    end.