%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2021, <ShiYue>
%%% @doc
%%% 节点接口
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_behavior).
-author("z.hua").

-include("ebt.hrl").
%% -----------------------------------------------
%% @doc 进入到当前节点
%% -----------------------------------------------
-callback on_enter(Rt, Tree, Node) -> no_return() when
    Rt   :: #ebt_rt{},
    Tree :: #ebt_tree{},
    Node :: #ebt_node{}.

%% -----------------------------------------------
%% @doc 返回到当前节点
%% -----------------------------------------------
-callback on_aback(Rt, Tree, Node) -> no_return() when
    Rt   :: #ebt_rt{},
    Tree :: #ebt_tree{},
    Node :: #ebt_node{}.

%% -----------------------------------------------
%% @doc 退出当前节点
%% -----------------------------------------------
-callback on_stop(Rt, Tree, Node) -> no_return() when
    Rt   :: #ebt_rt{},
    Tree :: #ebt_tree{},
    Node :: #ebt_node{}.

%%-----------------------------------------------------------------------------
%% API Functions
%%-----------------------------------------------------------------------------
-export([
    ahead/4,
    aback/3,
    leave/3,
    quit/1,
    stop/3
]).

%%-----------------------------------------------
%% @doc 进入下一个节点
-spec ahead(Rt, Tree, NextId, FromId) -> no_return() when
    Rt     :: #ebt_rt{},
    Tree   :: #ebt_tree{},
    NextId :: ebt:node_id(),
    FromId :: ebt:node_id().
%%-----------------------------------------------
ahead(Rt, Tree, NextId, FromId) ->
    Next = #ebt_node{executor = Mod} = ebt_runtime:get_node(Tree, NextId),
    NextResult = ebt_runtime:get_node_run_result(Rt, Tree#ebt_tree.id, NextId, ?INVALID),
    Phase = ?__if(NextResult == ?RUNNING, ?node_ahead_update_phase, ?node_ahead_enter_phase),
    case test_precondition(Rt, Next, Phase) of
        true  ->
            Rt1 = trace(Rt, Tree, Next),
            Rt2 = ebt_runtime:push_from(Rt1, FromId),
            Mod:on_enter(Rt2, Tree, Next);
        false ->
            Rt1 = ebt_runtime:set_node_run_result(Rt, NextId, ?FAILURE),
            leave_without_effector(Rt1, Tree, FromId)
    end.

%%-----------------------------------------------
%% @doc 返回上一个节点
-spec aback(Rt, Tree, Node) -> no_return() when
    Rt   :: #ebt_rt{},
    Tree :: #ebt_tree{},
    Node :: #ebt_node{}.
%%-----------------------------------------------
aback(Rt, Tree, Node) ->
    Rt1 = trace(Rt, Tree, Node),
    #ebt_node{executor = Mod} = Node,
    Mod:on_aback(Rt1, Tree, Node).

%%-----------------------------------------------
%% @doc 离开节点
-spec leave(Rt, Tree, Node) -> no_return() when
    Rt   :: #ebt_rt{},
    Tree :: #ebt_tree{},
    Node :: #ebt_node{}.
%%-----------------------------------------------
leave(Rt, Tree, Node) ->
    Rt1 = exec_effector(Rt, Node),
    {FromId, Rt2} = ebt_runtime:pop_from(Rt1),
    leave_without_effector(Rt2, Tree, FromId).

%%-----------------------------------------------
%% @doc 离开当前子树
-spec quit(Rt) -> no_return() when
    Rt :: #ebt_rt{}.
%%-----------------------------------------------
quit(Rt) ->
    [{Parent, NodeId} | Remain] = Rt#ebt_rt.tree_path,
    case Rt#ebt_rt.tree_path of
        [{Parent, -1} | Remain] ->
            Rt#ebt_rt{tree_id = Parent, tree_path = Remain};
        [{Parent, NodeId} | Remain] ->
            Rt1 = Rt#ebt_rt{tree_id = Parent, tree_path = Remain},
            Tree = ebt_runtime:get_tree(Parent),
            Node = ebt_runtime:get_node(Tree, NodeId),
            aback(Rt1, Tree, Node)
    end.

%%-----------------------------------------------
%% @doc 停止节点
-spec stop(Rt :: #ebt_rt{}, Tree :: #ebt_tree{}, StopNodeIds :: [integer()]) -> no_return().
%%-----------------------------------------------
stop(Rt, Tree, StopNodeId) when is_integer(StopNodeId) ->
    stop(Rt, Tree, [StopNodeId]);
stop(Rt, Tree, StopNodeIds) ->
    do_stop(StopNodeIds, Rt, Tree).

%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
test_precondition(_Rt, _Node = #ebt_node{preconditions = []}, _Phase) ->
    true;
test_precondition(Rt, Node, Phase) ->
    test_condition(Node#ebt_node.preconditions, Rt, Phase, ?__nil).

test_condition([Condition | T], Rt, Phase, Bool) ->
    #ebt_precondition{phase = CfgPhase, is_and = IsAnd, check = {compare, Op, Opl, Opr}} = Condition,
    case CfgPhase == both orelse CfgPhase == Phase of
        true ->
            Result = ebt_runtime:compare(Rt, Op, Opl, Opr),
            case Bool == ?__nil of
                true  ->
                    test_condition(T, Rt, Phase, Result);
                false ->
                    case IsAnd of
                        true  ->
                            case Bool andalso Result of
                                true  ->
                                    test_condition(T, Rt, Phase, true);
                                false ->
                                    false
                            end;
                        false ->
                            case Bool orelse Result of
                                true ->
                                    true;
                                false ->
                                    test_condition(T, Rt, Phase, false)
                            end
                    end
            end;
        false ->
            test_condition(T, Rt, Phase, Bool)
    end;
test_condition([], _Rt, _Phase, ?__nil) ->
    true;
test_condition([], _Rt, _Phase, Bool) ->
    Bool.

exec_effector(Rt, Node) ->
    case ebt_runtime:get_node_run_result(Rt, Node#ebt_node.id) of
        ?RUNNING ->
            Rt;
        RunResult ->
            do_exec_effector(Node#ebt_node.effectors, RunResult, Rt)
    end.

do_exec_effector([Effector | T], RunResult, Rt) ->
    #ebt_effector{phase = Phase, action = Action} = Effector,
    case Phase == both orelse Phase == RunResult of
        true ->
            Rt1 = case Action of
                      {assign, Opl, Opr} ->
                          ebt_runtime:assign(Rt, Opl, Opr);
                      {compute, Op, Var, OprA, OprB} ->
                          ebt_runtime:compute(Rt, Op, Var, OprA, OprB)
                  end,
            do_exec_effector(T, RunResult, Rt1);
        false ->
            do_exec_effector(T, RunResult, Rt)
    end;
do_exec_effector([], _RunResult, Rt) ->
    Rt.

leave_without_effector(Rt, Tree, FromId) ->
    case FromId == -1 of
        true when Rt#ebt_rt.tree_path =/= [] ->
            quit(Rt);
        true  ->
            Rt;
        false ->
            aback(Rt, Tree, ebt_runtime:get_node(Tree, FromId))
    end.

do_stop([], Rt, _Tree) ->
    Rt;
do_stop([NodeId | T], Rt, Tree) ->
    Node = #ebt_node{executor = Mod} = ebt_runtime:get_node(Tree, NodeId),
    Rt1 = Mod:on_stop(Rt, Tree, Node),
    do_stop(T, Rt1, Tree).

-ifdef(TEST).

trace(Rt, Tree, Node) ->
    Rt#ebt_rt{tracing = [{Tree#ebt_tree.id,Node#ebt_node.id} | Rt#ebt_rt.tracing]}.

-else.

trace(Rt, _Tree, _Node) ->
    Rt.

-endif.
