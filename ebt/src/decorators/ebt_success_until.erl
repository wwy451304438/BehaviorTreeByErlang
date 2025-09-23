%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 18. 7月 2024 9:12
%%%-------------------------------------------------------------------
-module(ebt_success_until).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(remain_count, {?MODULE, '__remain_count__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{children = [ChildId]}) ->
    ebt_behavior:ahead(Rt, Tree, ChildId, Node#ebt_node.id).

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId, children = [ChildId]}) ->
    ChildResult = ebt_runtime:get_node_run_result(Rt, ChildId),
    Rt1 = case Node#ebt_node.decorator_when_child_end of
              true when ?is_running(ChildResult) ->
                  ebt_runtime:set_node_run_result(Rt, NodeId, ChildResult);
              _ ->
                  update_remain_count(Rt, Node)
          end,
    ebt_behavior:leave(Rt1, Tree, Node).

on_stop(Rt, Tree = #ebt_tree{id = TreeId},  #ebt_node{id = NodeId, children = [ChildId]}) ->
    Rt1 = ?__if(ebt_runtime:get_node_run_result(Rt, TreeId, ChildId, ?INVALID) == ?RUNNING, ebt_behavior:stop(Rt, Tree, ChildId), Rt),
    ebt_runtime:clr_node_run_result(Rt1, TreeId, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
update_remain_count(Rt, Node = #ebt_node{id = NodeId}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?remain_count) of
        ?__nil ->
            Count = ebt_runtime:get_property_as_operand(Rt, Node, count),
            Count1 = ?__if(Count =< 0, Count, Count - 1),
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_count, Count1),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?SUCCESS);
        RemainCount when RemainCount < 0 ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?SUCCESS);
        RemainCount when RemainCount > 0 ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_count, RemainCount - 1),
            ebt_runtime:set_node_run_result(Rt1, NodeId, ?SUCCESS);
        _ ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE)
    end.