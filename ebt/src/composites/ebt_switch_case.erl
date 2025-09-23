%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 14:38
%%%-------------------------------------------------------------------
-module(ebt_switch_case).
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

on_enter(Rt, Tree, #ebt_node{id = NodeId, children = [JudgeId, _]}) ->
    Rt1 = ebt_runtime:set_status(Rt, NodeId, ?child_id, JudgeId),
    ebt_behavior:ahead(Rt1, Tree, JudgeId, NodeId).

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId, children = [JudgeId, TrueId]}) ->
    JudgeResult = ebt_runtime:get_node_run_result(Rt, JudgeId),
    case ebt_runtime:get_status(Rt, NodeId, ?child_id) of
        JudgeId when ?is_success(JudgeResult) ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?child_id, TrueId),
            ebt_behavior:ahead(Rt1, Tree, TrueId, NodeId);
        JudgeId ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, JudgeResult),
            Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
            ebt_behavior:leave(Rt2, Tree, Node);
        TrueId ->
            TrueResult = ebt_runtime:get_node_run_result(Rt, TrueId),
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, TrueResult),
            Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
            ebt_behavior:leave(Rt2, Tree, Node)
    end.

on_stop(Rt, Tree, #ebt_node{id = NodeId, children = [_, TrueId]}) ->
    Rt1 = ebt_behavior:stop(Rt, Tree, TrueId),
    Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
    ebt_runtime:clr_node_run_result(Rt2, Tree#ebt_tree.id, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------