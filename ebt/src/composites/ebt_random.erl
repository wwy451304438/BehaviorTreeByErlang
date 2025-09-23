%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 11:21
%%%-------------------------------------------------------------------
-module(ebt_random).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(child, {?MODULE, '__child__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, #ebt_node{id = NodeId, children = Children}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?child) of
        ?__nil ->
            WtList  = [
                begin
                    Child = ebt_runtime:get_node(Tree, ChildId),
                    ebt_runtime:get_property_as_operand(Rt, Child, weight)
                end || ChildId <- Children],
            HitNth  = weight_random(WtList),
            ChildId = lists:nth(HitNth, Children),
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?child, ChildId),
            ebt_behavior:ahead(Rt1, Tree, ChildId, NodeId);
        ChildId ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?child, ChildId),
            ebt_behavior:ahead(Rt1, Tree, ChildId, NodeId)
    end.

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    ChildId = ebt_runtime:get_status(Rt, NodeId, ?child),
    ChildRunResult = ebt_runtime:get_node_run_result(Rt, ChildId),
    Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ChildRunResult),
    Rt2 = ?__if(ChildRunResult == ?RUNNING, Rt1, ebt_runtime:clr_status(Rt1, NodeId)),
    ebt_behavior:leave(Rt2, Tree, Node).

on_stop(Rt, Tree, #ebt_node{id = NodeId}) ->
    ChildId = ebt_runtime:get_status(Rt, NodeId, ?child),
    Rt1 = ?__if(ChildId == ?__nil, Rt, ebt_behavior:stop(Rt, Tree, ChildId)),
    Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
    ebt_runtime:clr_node_run_result(Rt2, Tree#ebt_tree.id, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
weight_random(WtList) ->
    Rand = rand:uniform(lists:sum(WtList)),
    weight_random2(WtList, Rand, 1, 0).

weight_random2([Wt | _], Rand, Nth, AccSum) when Rand =< AccSum+Wt ->
    Nth;
weight_random2([Wt | T], Rand, Nth, AccSum) ->
    weight_random2(T, Rand, Nth+1, AccSum+Wt).
