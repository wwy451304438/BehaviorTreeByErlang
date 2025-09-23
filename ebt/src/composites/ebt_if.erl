%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 9:41
%%%-------------------------------------------------------------------
-module(ebt_if).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(child_id, {?MODULE, '__child_id__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, #ebt_node{id = NodeId, children = [JudgeId, _, _]}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?child_id) of
        ?__nil ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?child_id, JudgeId),
            ebt_behavior:ahead(Rt1, Tree, JudgeId, NodeId);
        ChildId ->
            ebt_behavior:ahead(Rt, Tree, ChildId, NodeId)
    end.

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId, children = [JudgeId, TrueId, FalseId]}) ->
    JudgeResult = ebt_runtime:get_node_run_result(Rt, JudgeId),
    case ebt_runtime:get_status(Rt, NodeId, ?child_id) of
        JudgeId when ?is_success(JudgeResult) ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?child_id, TrueId),
            ebt_behavior:ahead(Rt1, Tree, TrueId, NodeId);
        JudgeId when ?is_failure(JudgeResult) ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?child_id, FalseId),
            ebt_behavior:ahead(Rt1, Tree, FalseId, NodeId);
        JudgeId ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, JudgeResult),
            Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
            ebt_behavior:leave(Rt2, Tree, Node);
        TrueId ->
            execute_action(Rt, Tree, Node, TrueId);
        FalseId ->
            execute_action(Rt, Tree, Node, FalseId)
    end.

on_stop(Rt, Tree, #ebt_node{id = NodeId}) ->
    ChildId = ebt_runtime:get_status(Rt, NodeId, ?child_id),
    Rt1 = ?__if(ChildId == ?__nil, Rt, ebt_behavior:stop(Rt, Tree, ChildId)),
    Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
    ebt_runtime:clr_node_run_result(Rt2, Tree#ebt_tree.id, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
execute_action(Rt, Tree, Node = #ebt_node{id = NodeId}, ActionId) ->
    ActionResult = ebt_runtime:get_node_run_result(Rt, ActionId),
    Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ActionResult),
    case ?is_running(ActionResult) of
        true ->
            ebt_behavior:leave(Rt1, Tree, Node);
        false ->
            Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
            ebt_behavior:leave(Rt2, Tree, Node)
    end.