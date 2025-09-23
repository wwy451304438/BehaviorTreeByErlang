%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 16:10
%%%-------------------------------------------------------------------
-module(ebt_or).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(remain_child, {?MODULE, '__remain_child__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildId | _]}) ->
    Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_child, Node#ebt_node.children),
    ebt_behavior:ahead(Rt1, Tree, ChildId, NodeId).

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    [PreChildId | RemainChild] = ebt_runtime:get_status(Rt, NodeId, ?remain_child),
    case ebt_runtime:get_node_run_result(Rt, PreChildId) of
        ?FAILURE when RemainChild == [] ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE),
            Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
            ebt_behavior:leave(Rt2, Tree, Node);
        ?FAILURE ->
            [NextChildId | _] = RemainChild,
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_child, RemainChild),
            ebt_behavior:ahead(Rt1, Tree, NextChildId, NodeId);
        ?SUCCESS ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?SUCCESS),
            Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
            ebt_behavior:leave(Rt2, Tree, Node)
    end.

on_stop(Rt, Tree, Node) ->
    Rt1 = ebt_runtime:clr_status(Rt, Node#ebt_node.id),
    ebt_runtime:clr_node_run_result(Rt1, Tree#ebt_tree.id, Node#ebt_node.id).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------