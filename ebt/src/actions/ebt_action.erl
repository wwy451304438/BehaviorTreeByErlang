%%%-------------------------------------------------------------------
%%% @author wwy
%%% @copyright (C) 2024, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. 7月 2024 16:47
%%%-------------------------------------------------------------------
-module(ebt_action).
-author("wwy").

-behavior(ebt_behavior).

-include("ebt.hrl").

%%-----------------------------------------------------------------------------
%% API Functions
%%-----------------------------------------------------------------------------
-export([
    on_enter/3,
    on_aback/3,
    on_stop/3
]).

on_enter(Rt, Tree, Node) ->
    RunResult = ebt_runtime:get_node_run_result(Rt, Tree#ebt_tree.id, Node#ebt_node.id, ?INVALID),
    Phase = ?__if(RunResult == ?RUNNING, ?node_ahead_update_phase, ?node_ahead_enter_phase),
    Result = execute(Rt, Node, Phase),
    Rt1 = ebt_runtime:set_node_run_result(Rt, Node#ebt_node.id, Result),
    ebt_behavior:leave(Rt1, Tree, Node).

on_aback(_Rt, _Tree, _Node) ->
    erlang:error(not_implemented).

on_stop(Rt, #ebt_tree{id = TreeId}, #ebt_node{id = NodeId}) ->
%%    RunResult = ebt_runtime:get_node_run_result(Rt, TreeId, NodeId, ?INVALID),
%%    ?__if(RunResult == ?RUNNING, execute(Rt, Node, ?node_ahead_stop_phase)),
    ebt_runtime:clr_node_run_result(Rt, TreeId, NodeId).

%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
execute(Rt, Node, Phase) ->
    {func, Mod, Func, Args} = ebt_runtime:get_property(Node, action),
    Result1 = ebt_runtime:execute(Rt, Mod, Phase, Func, Args),
    fix_result(ebt_runtime:get_property(Node, result), Result1, Rt, Phase).

fix_result(?INVALID, Return, _Rt, _Phase) ->
    Return;
fix_result(?SUCCESS, _Return, _Rt, _Phase) ->
    ?SUCCESS;
fix_result(?FAILURE, _Return, _Rt, _Phase) ->
    ?FAILURE;
fix_result(?RUNNING, _Return, _Rt, _Phase) ->
    ?RUNNING;
fix_result({func,Mod,Func,[]}, _Return, Rt, Phase) ->
    ebt_runtime:execute(Rt, Mod, Phase, Func, []);
fix_result({func,Mod,Func,_Args}, Return, Rt, Phase) ->
    ebt_runtime:execute(Rt, Mod, Phase, Func, [Return]).
