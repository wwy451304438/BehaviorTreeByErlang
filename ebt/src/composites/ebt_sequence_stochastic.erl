%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 14:15
%%%-------------------------------------------------------------------
-module(ebt_sequence_stochastic).
-author("wwy").
-behavior(ebt_behavior).

-include("ebt.hrl").

-define(remain_child, {?MODULE, '__remain_child__'}).
-define(interrupt, {?MODULE, '__interrupt__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node) ->
    case ebt_runtime:get_status(Rt, Node#ebt_node.id, ?remain_child) of
        ?__nil ->
            run_child(Rt, Tree, Node, ebt_runtime:shuffle(Node#ebt_node.children));
        RemainChild ->
            run_child(Rt, Tree, Node, RemainChild)
    end.

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?interrupt, false) of
        true ->
            #ebt_node{interrupt = [InterruptId]} = Node,
            case ebt_runtime:get_node_run_result(Rt, InterruptId) of
                ?SUCCESS ->
                    Rt1 = ebt_runtime:clr_status(Rt, NodeId),
                    Rt2 = ebt_runtime:set_node_run_result(Rt1, NodeId, ?FAILURE),
                    ebt_behavior:leave(Rt2, Tree, Node);
                ?FAILURE ->
                    Rt1 = ebt_runtime:clr_status(Rt, NodeId, ?interrupt),
                    action_aback(Rt1, Tree, Node)
            end;
        false ->
            action_aback(Rt, Tree, Node)
    end.

on_stop(Rt, Tree, #ebt_node{id = NodeId}) ->
    Rt1 = case ebt_runtime:get_status(Rt, NodeId, ?remain_child) of
              [RunningChildId | _] ->
                  ebt_behavior:stop(Rt, Tree, RunningChildId);
              [] ->
                  Rt
          end,
    Rt1 = ebt_runtime:clr_status(Rt, NodeId),
    ebt_runtime:clr_node_run_result(Rt1, Tree#ebt_tree.id, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
action_aback(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    [PreChildId | RemainChild] = ebt_runtime:get_status(Rt, NodeId, ?remain_child),
    case ebt_runtime:get_node_run_result(Rt, PreChildId) of
        ?FAILURE ->
            Rt1 = ebt_runtime:clr_status(Rt, NodeId),
            Rt2 = ebt_runtime:set_node_run_result(Rt1, NodeId, ?FAILURE),
            ebt_behavior:leave(Rt2, Tree, Node);
        ?RUNNING ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?RUNNING),
            ebt_behavior:leave(Rt1, Tree, Node);
        ?SUCCESS when RemainChild == [] ->
            Rt1 = ebt_runtime:clr_status(Rt, NodeId),
            Rt2 = ebt_runtime:set_node_run_result(Rt1, NodeId, ?SUCCESS),
            ebt_behavior:leave(Rt2, Tree, Node);
        ?SUCCESS ->
            run_child(Rt, Tree, Node, RemainChild)
    end.

run_child(Rt, Tree, Node = #ebt_node{id = NodeId}, RemainChild = [NextChildId | _]) ->
    case Node#ebt_node.interrupt of
        [InterruptId] ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?interrupt, true),
            ebt_behavior:ahead(Rt1, Tree, InterruptId, NodeId);
        _ ->
            Rt1 = ebt_runtime:clr_status(Rt, NodeId, ?interrupt),
            Rt2 = ebt_runtime:set_status(Rt1, NodeId, ?remain_child, RemainChild),
            ebt_behavior:ahead(Rt2, Tree, NextChildId, NodeId)
    end.