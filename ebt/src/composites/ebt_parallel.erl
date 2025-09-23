%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 7月 2024 10:21
%%%-------------------------------------------------------------------
-module(ebt_parallel).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

%% 决定并行条件在什么条件下失败
-define(FAIL_POLICY_ONE, 0).
-define(FAIL_POLICY_ALL, 1).

%% 决定并行节点在什么条件下是成功
-define(SUCCESS_POLICY_ONE, 0).
-define(SUCCESS_POLICY_ALL, 1).

%% 子节点结束后是重新再循环执行，还是结束后不再执行
-define(CHILD_FINISH_ONCE, 0).
-define(CHILD_FINISH_LOOP, 1).

%% 当并行节点的成功或失败条件满足并返回成功或失败后，是否需要终止掉其他还在运行的子节点
-define(EXIT_POLICY_NONE, 0).
-define(EXIT_POLICY_RUNNINGSIBLINGS, 1).

-define(ran_child, {?MODULE, '__ran_child__'}).
-define(remain_child, {?MODULE, '__remain_child__'}).
-define(child_run_result, {?MODULE, '__child_run_result__'}).

%% API
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    case select_child(Rt, Node) of
        [] ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE),
            ebt_behavior:leave(Rt1, Tree, Node);
        RemainChild = [ChildId | _] ->
            Rt1 = ebt_runtime:set_status(Rt, NodeId, ?remain_child, RemainChild),
            ebt_behavior:ahead(Rt1, Tree, ChildId, NodeId)
    end.

on_aback(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    [PreChildId | RemainChild] = ebt_runtime:get_status(Rt, NodeId, ?remain_child),
    ExitPolicy = ebt_runtime:get_property(Node, exit_policy),
    Rt1 = add_child_run_result(Rt, Node, PreChildId),
    Rt2 = add_ran_child(Rt1, Node, PreChildId),
    case check_exit(Rt2, Node) of
        {ok, Result} when ExitPolicy == ?EXIT_POLICY_RUNNINGSIBLINGS ->
            Rt3 = ebt_behavior:stop(Rt2, Tree, RemainChild),
            Rt4 = ebt_runtime:set_node_run_result(Rt3, NodeId, Result),
            Rt5 = ebt_runtime:clr_status(Rt4, NodeId, ?child_run_result),
            ebt_behavior:leave(Rt5, Tree, Node);
        _ ->
            case RemainChild of
                [] ->
                    finish_run_result(Rt2, Tree, Node);
                [NextChildId | _] ->
                    Rt3 = ebt_runtime:set_status(Rt2, NodeId, ?remain_child, RemainChild),
                    ebt_behavior:ahead(Rt3, Tree, NextChildId, NodeId)
            end
    end.

on_stop(Rt, Tree, #ebt_node{id = NodeId}) ->
    RemainChild = ebt_runtime:get_status(Rt, NodeId, ?remain_child, []),
    Rt1 = ebt_behavior:stop(Rt, Tree, RemainChild),
    Rt2 = ebt_runtime:clr_status(Rt1, NodeId),
    ebt_runtime:clr_node_run_result(Rt2, Tree#ebt_tree.id, NodeId).
%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
finish_run_result(Rt, Tree, Node = #ebt_node{id = NodeId}) ->
    ChildRunResult = ebt_runtime:get_status(Rt, NodeId, ?child_run_result),
    CheckSuccess = check_success(Node, ChildRunResult),
    CheckFail = check_fail(Node, ChildRunResult),
    Rt1 = case true of
        _ when CheckFail ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?FAILURE);
        _ when CheckSuccess ->
            ebt_runtime:set_node_run_result(Rt, NodeId, ?SUCCESS);
        _ ->
            HaveRunning = have_running(ChildRunResult),
            Result = ?__if(HaveRunning, ?RUNNING, ?FAILURE),
            ebt_runtime:set_node_run_result(Rt, NodeId, Result)
    end,
    Rt2 = ebt_runtime:clr_status(Rt1, NodeId, ?child_run_result),
    ebt_behavior:leave(Rt2, Tree, Node).

check_exit(Rt, Node) ->
    ChildRunResult = [ChildResult | _] = ebt_runtime:get_status(Rt, Node#ebt_node.id, ?child_run_result),
    CheckSuccess = check_success(Node, ChildRunResult),
    CheckFail = check_fail(Node,ChildRunResult),
    case ?run_finish(ChildResult) of
        true when CheckFail ->
            {ok, ?FAILURE};
        true when CheckSuccess ->
            {ok, ?RUNNING};
        _ ->
            false
    end.

check_success(Node, ChildRunResult) ->
    SuccessPolicy = ebt_runtime:get_property(Node, succeed_policy),
    check_success(Node, ChildRunResult, SuccessPolicy).

check_success(_Node, ChildRunResult, ?SUCCESS_POLICY_ONE) ->
    lists:member(?SUCCESS, ChildRunResult);
check_success(Node, ChildRunResult, ?SUCCESS_POLICY_ALL) ->
    SuccessCount = lists:foldl(
        fun(ChildrenResult, Count) ->
            ?__if(ChildrenResult == ?SUCCESS, Count + 1, Count)
        end, 0, ChildRunResult),
    SuccessCount == length(Node#ebt_node.children).

check_fail(Node, ChildRunResult) ->
    SuccessPolicy = ebt_runtime:get_property(Node, fail_policy),
    check_fail(Node, ChildRunResult, SuccessPolicy).

check_fail(_Node, ChildRunResult, ?FAIL_POLICY_ONE) ->
    lists:member(?FAILURE, ChildRunResult);
check_fail(Node, ChildRunResult, ?FAIL_POLICY_ALL) ->
    FailCount = lists:foldl(
        fun(ChildrenResult, Count) ->
            ?__if(ChildrenResult == ?FAILURE, Count + 1, Count)
        end, 0, ChildRunResult),
    FailCount == length(Node#ebt_node.children).

have_running(AllChildrenResult) ->
    lists:any(
        fun(ChildrenResult) ->
            ChildrenResult == ?RUNNING
        end, AllChildrenResult).

select_child(Rt, Node) ->
    case ebt_runtime:get_property(Node, child_finish_policy) == ?CHILD_FINISH_ONCE of
        true ->
            RanChild = ebt_runtime:get_status(Rt, Node#ebt_node.id, ?ran_child, []),
            lists:filter(
                fun(ChildId) ->
                    not lists:member(ChildId, RanChild)
                end, Node#ebt_node.children);
        false ->
            Node#ebt_node.children
    end.

add_child_run_result(Rt, Node, ChildId) ->
    ChildResult = ebt_runtime:get_node_run_result(Rt, ChildId),
    ChildRunResult = ebt_runtime:get_status(Rt, Node#ebt_node.id, ?child_run_result, []),
    ChildRunResult1 = [ChildResult | ChildRunResult],
    ebt_runtime:set_status(Rt, Node#ebt_node.id, ?child_run_result, ChildRunResult1).

add_ran_child(Rt, Node, ChildId) ->
    RanChild = ebt_runtime:get_status(Rt, Node#ebt_node.id, ?ran_child, []),
    RanChild1 = lists:uniq([ChildId | RanChild]),
    ebt_runtime:set_status(Rt, Node#ebt_node.id, ?ran_child, RanChild1).