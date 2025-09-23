%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 14:17
%%%-------------------------------------------------------------------
-module(ebt_subtree).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node) ->
    SubId = ebt_runtime:get_property_as_operand(Rt, Node, subtree),
    Rt1 = Rt#ebt_rt{
        tree_id   = SubId,
        tree_path = [{Tree#ebt_tree.id, Node#ebt_node.id} | Rt#ebt_rt.tree_path]
    },
    Tree1 = ebt_runtime:get_tree(SubId),
    ebt_behavior:ahead(Rt1, Tree1, Tree1#ebt_tree.entry, -1).

on_aback(Rt, Tree, Node) ->
    SubId = ebt_runtime:get_property_as_operand(Rt, Node, subtree),
    Tree1 = ebt_runtime:get_tree(SubId),
    SubTreeResult = ebt_runtime:get_node_run_result(Rt, SubId, Tree1#ebt_tree.entry),
    Rt1 = ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, SubTreeResult),
    ebt_behavior:leave(Rt1, Tree, Node).

on_stop(Rt, Tree, Node) ->
    ebt_runtime:clr_node_run_result(Rt, Tree#ebt_tree.id, Node#ebt_node.id).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
