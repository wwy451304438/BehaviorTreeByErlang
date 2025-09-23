%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 9:28
%%%-------------------------------------------------------------------
-module(ebt_noop).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node) ->
    Rt1 = ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, ?SUCCESS),
    ebt_behavior:leave(Rt1, Tree, Node).

on_aback(_Rt, _Tree, _Node) ->
    erlang:error(not_implemented).

on_stop(Rt, Tree, Node) ->
    ebt_runtime:clr_node_run_result(Rt, Tree#ebt_tree.id, Node#ebt_node.id).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------