%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 9:29
%%%-------------------------------------------------------------------
-module(ebt_wait).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(end_time, {?MODULE, '__end_time__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    Now = ebt_runtime:timestamp(),
    Rt2 = case ebt_runtime:get_status(Rt, NodeId, ?end_time) of
        ?__nil ->
            Millis = ebt_runtime:get_property_as_operand(Rt, Node, time),
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?end_time, Now + Millis),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?RUNNING);
        End when Now =< End ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?RUNNING);
        _End ->
            Rt1 = ebt_runtime:clr_status(Rt, NodeId),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?SUCCESS)
    end,
    ebt_behavior:leave(Rt2, Tree, Node).

on_aback(_Rt, _Tree, _Node) ->
    erlang:error(not_implemented).

on_stop(Rt, Tree, Node) ->
    Rt1 = ebt_runtime:clr_status(Rt, Node#ebt_node.id),
    ebt_runtime:clr_node_run_result(Rt1, Tree#ebt_tree.id, Node#ebt_node.id).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------