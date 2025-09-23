%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 16:17
%%%-------------------------------------------------------------------
-module(ebt_condition).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node) ->
    {Op, Opl, Opr} = ebt_runtime:get_property(Node, compare),
    Result = ?__if(ebt_runtime:compare(Rt, Op, Opl, Opr), ?SUCCESS, ?FAILURE),
    Rt1 = ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, Result),
    ebt_behavior:leave(Rt1, Tree, Node).

on_aback(_Rt, _Tree, _Node) ->
    erlang:error(not_implemented).

on_stop(Rt, Tree, Node) ->
    ebt_runtime:clr_node_run_result(Rt, Tree#ebt_tree.id, Node#ebt_node.id).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------