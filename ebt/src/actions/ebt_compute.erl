%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 9:16
%%%-------------------------------------------------------------------
-module(ebt_compute).
-author("wwy").

-behaviour(ebt_behavior).

-include("ebt.hrl").

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node) ->
    {Op, Var, OprA, OprB} = ebt_runtime:get_property(Node, compute),
    Rt1 = ebt_runtime:compute(Rt, Op, Var, OprA, OprB),
    Rt2 = ebt_runtime:set_node_run_result(Rt1, Node#ebt_node.id, ?SUCCESS),
    ebt_behavior:leave(Rt2, Tree, Node).

on_aback(_Rt, _Tree, _Node) ->
    erlang:error(not_implemented).

on_stop(Rt, Tree, Node) ->
    ebt_runtime:clr_node_run_result(Rt, Tree#ebt_tree.id, Node#ebt_node.id).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------