%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 15:36
%%%-------------------------------------------------------------------
-module(ebt_waitfor_signal).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

-define(interrupt, {?MODULE, '__interrupt__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    case Node of
        #ebt_node{interrupt = [InterruptId]} ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?interrupt, true),
            ebt_behavior:ahead(Rt1, Tree, InterruptId, NodeId);
        _ ->
            run_child(Rt, Tree, Node)
    end.

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    case ebt_runtime:get_status(Rt, NodeId, ?interrupt, false) of
        true ->
            #ebt_node{interrupt = [InterruptId]} = Node,
            Rt1 = ebt_runtime:clr_status(Rt, NodeId, ?interrupt),
            case ebt_runtime:get_node_run_result(Rt, InterruptId) of
                ?SUCCESS ->
                    run_child(Rt1, Tree, Node);
                _ ->
                    Rt2 = ebt_runtime:set_node_run_result(Rt1, NodeId, ?RUNNING),
                    Rt3 = ebt_runtime:clr_status(Rt2, NodeId),
                    ebt_behavior:leave(Rt3, Tree, Node)
            end;
        false ->
            #ebt_node{children = [ChildId]} = Node,
            ChildResult = ebt_runtime:get_node_run_result(Rt, ChildId),
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ChildResult),
            ebt_behavior:leave(Rt1, Tree, Node)
    end.

on_stop(Rt, Tree = #ebt_tree{id = TreeId}, Node = #ebt_node{id = NodeId}) ->
    ChildId1 = case Node of
        #ebt_node{interrupt = [InterruptId]} ->
            InterruptId;
        #ebt_node{children = [ChildId]} ->
            ChildId
    end,
    RunResult = ebt_runtime:get_node_run_result(Rt, TreeId, ChildId1, ?INVALID),
    Rt1 = ?__if(RunResult == ?RUNNING, ebt_behavior:stop(Rt, Tree, ChildId1), Rt),
    Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
    ebt_runtime:clr_node_run_result(Rt2, TreeId, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
run_child(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    case Node of
        #ebt_node{children = [ChildId]} ->
            ebt_behavior:ahead(Rt, Tree, ChildId, NodeId);
        _ ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?SUCCESS),
            Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
            ebt_behavior:leave(Rt2, Tree, Node)
    end.