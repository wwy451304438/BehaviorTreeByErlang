%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2021, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_runtime).
-author("z.hua").

-include("ebt.hrl").

-include_lib("eunit/include/eunit.hrl").

%%-----------------------------------------------------------------------------
%% API Functions
%%-----------------------------------------------------------------------------
-export([
    get_manager/0,
    set_manager/1,

    get_tree/1,
    get_node/2,

    get_status/3, get_status/4,
    set_status/4,
    clr_status/2, clr_status/3,

    get_variant/2,
    set_variant/3,

    push_from/2,
    pop_from/1,
    clr_from/1, clr_from/2,

    get_operand/2,

    get_property/2,
    get_property_as_operand/3,

    timestamp/0,
    shuffle/1,
    run_subtree/4,

    compare/4,
    assign/3,
    execute/4, execute/5,
    compute/5,

    log_msg/2,

    set_node_run_result/3,
    get_node_run_result/2, get_node_run_result/3, get_node_run_result/4,
    clr_node_run_result/3
]).

get_manager() ->
    get({?MODULE,dict_bt_manager}).

set_manager(Mgr) ->
    put({?MODULE,dict_bt_manager}, Mgr).


get_tree(TreeId) ->
    #ebt_mgr{get_tree = GetTree} = get_manager(),
    case GetTree(TreeId) of
        ?__nil ->
            throw({tree_not_found, TreeId});
        Tree ->
            Tree
    end.

get_node(Tree, NodeId) ->
    maps:get(NodeId, Tree#ebt_tree.nodes).

get_status(Rt, NodeId, Key) ->
    get_status(Rt, NodeId, Key, ?__nil).

get_status(Rt, NodeId, Key, Default) ->
    Status = maps:get({Rt#ebt_rt.tree_id,NodeId}, Rt#ebt_rt.status, #{}),
    maps:get(Key, Status, Default).

set_status(Rt, NodeId, Key, Val) ->
    Status  = maps:get({Rt#ebt_rt.tree_id,NodeId}, Rt#ebt_rt.status, #{}),
    Status2 = maps:put(Key, Val, Status),
    Rt#ebt_rt{status = maps:put({Rt#ebt_rt.tree_id,NodeId}, Status2, Rt#ebt_rt.status)}.

clr_status(Rt, NodeId) ->
    Rt#ebt_rt{status = maps:remove({Rt#ebt_rt.tree_id,NodeId}, Rt#ebt_rt.status)}.

clr_status(Rt, NodeId, Key) ->
    Status = maps:get({Rt#ebt_rt.tree_id, NodeId}, Rt#ebt_rt.status, #{}),
    Status1 = maps:remove(Key, Status),
    Rt#ebt_rt{status = maps:put({Rt#ebt_rt.tree_id,NodeId}, Status1, Rt#ebt_rt.status)}.

get_variant(Rt, Var) ->
    Mod = element(1, Rt#ebt_rt.agent),
    Mod:get_var(Rt#ebt_rt.agent, Var).

set_variant(Rt, Var, Val) ->
    Mod = element(1, Rt#ebt_rt.agent),
    Mod:set_var(Rt#ebt_rt.agent, Var, Val).


push_from(Rt, FromId) ->
    Rt#ebt_rt{node_path = [{Rt#ebt_rt.tree_id, FromId} | Rt#ebt_rt.node_path]}.

pop_from(Rt) ->
    case Rt#ebt_rt.node_path of
        [{_TreeId, NodeId} | T] ->
            {NodeId, Rt#ebt_rt{node_path = T}};
        _ ->
            {-1, Rt}
    end.

clr_from(Rt) ->
    Rt#ebt_rt{node_path = []}.

clr_from(Rt, TreeId) ->
    Rt#ebt_rt{node_path = [E || E = {TreeId2,_} <- Rt#ebt_rt.node_path, TreeId /= TreeId2]}.


%% 获取操作数
%% 变量
get_operand({var, Var}, Rt) ->
    get_variant(Rt, Var);
%% 数组
get_operand({var, Var, Index}, Rt) ->
    List = get_variant(Rt, Var),
    Idx2 = get_operand(Index, Rt) + 1,
    case Idx2 =< length(List) of
        true  ->
            lists:nth(Idx2, List);
        false ->
            throw(index_out_of_range)
    end;
%% 事件参数
get_operand({par, Index}, _Rt = #ebt_rt{params = Params}) ->
    Idx2 = Index + 1,
    case Idx2 =< length(Params) of
        true  ->
            lists:nth(Idx2, Params);
        false ->
            throw(index_out_of_range)
    end;
%% 函数返回值
get_operand({func, Mod, Func, Args}, Rt) ->
    Args2 = [get_operand(A, Rt) || A <- Args],
    Mod:Func(Rt#ebt_rt.agent, ?node_ahead_enter_phase, Args2);
get_operand(List, Rt) when is_list(List) ->
    [get_operand(E, Rt) || E <- List];
%% 常量
get_operand(Const, _Rt) ->
    Const.

%% 获取节点属性
get_property(Node, Key) ->
    proplists:get_value(Key, Node#ebt_node.property).

%% 获取节点属性作为操作数
get_property_as_operand(Rt, Node, Key) ->
    get_operand(proplists:get_value(Key, Node#ebt_node.property), Rt).


%% 获取系统时间(毫秒)
timestamp() ->
    erlang:system_time(millisecond).

shuffle(List) ->
    Max = length(List) + 10000,
    [E || {_, E} <- lists:sort([{rand:uniform(Max), X} || X <- List])].

run_subtree(Rt, _Tree, Subtree, _Transfer = true) ->
    Rt2 = Rt#ebt_rt{
        tree_id   = Subtree,
        node_path = [],
        tree_path = [],
        status    = #{}
    },
    Tree2 = ebt_runtime:get_tree(Subtree),
    ebt_behavior:ahead(Rt2, Tree2, Tree2#ebt_tree.entry, -1);
run_subtree(Rt, Tree, Subtree, _Transfer = false) ->
    Rt1 = Rt#ebt_rt{
        tree_id   = Subtree,
        tree_path = [{Tree#ebt_tree.id, -1} | Rt#ebt_rt.tree_path]
    },
    Tree1 = get_tree(Subtree),
    ebt_behavior:ahead(Rt1, Tree1, Tree1#ebt_tree.entry, -1).


compare(Rt, Op, Opl0, Opr0) ->
    Opl = ebt_runtime:get_operand(Opl0, Rt),
    Opr = ebt_runtime:get_operand(Opr0, Rt),
    case Op of
        '==' -> Opl =:= Opr;
        '!=' -> Opl =/= Opr;
        '>'  -> Opl > Opr;
        '>=' -> Opl >= Opr;
        '<'  -> Opl < Opr;
        '<=' -> Opl =< Opr
    end.

assign(Rt, {var,Var}, Opr) ->
    Rt#ebt_rt{agent = set_variant(Rt, Var, get_operand(Opr, Rt))};
assign(Rt, {var,Var,Index}, Opr) ->
    List1 = get_variant(Rt, Var),
    ?__if(Index > length(List1), throw(index_out_of_range), ok),
    List2 = assign_array(List1, Index+1, get_operand(Opr, Rt)),
    Rt#ebt_rt{agent = set_variant(Rt, Var, List2)}.

execute(Rt, Mod, Func, Args) ->
    Mod:Func(Rt#ebt_rt.agent, get_operand(Args, Rt)).

execute(Rt, Mod, Phase, Func, Args) ->
    Mod:Func(Rt#ebt_rt.agent, Phase, get_operand(Args, Rt)).

compute(Rt, Op, Var, OprA0, OprB0) ->
    OprA = get_operand(OprA0, Rt),
    OprB = get_operand(OprB0, Rt),
    Val = case Op of
        '+' -> OprA + OprB;
        '-' -> OprA - OprB;
        '*' -> OprA * OprB;
        '/' -> round(OprA / OprB)
    end,
    assign(Rt, Var, Val).

log_msg(Fmt, Args) ->
    #ebt_mgr{logger = Logger} = get_manager(),
    Logger(Fmt, Args).

set_node_run_result(Rt, NodeId, Result) ->
    NodeRunResult1 = maps:put({Rt#ebt_rt.tree_id, NodeId}, Result, Rt#ebt_rt.node_run_result),
    Rt#ebt_rt{node_run_result = NodeRunResult1}.

get_node_run_result(Rt, NodeId) ->
    maps:get({Rt#ebt_rt.tree_id, NodeId}, Rt#ebt_rt.node_run_result).

get_node_run_result(Rt, TreeId, NodeId) ->
    maps:get({TreeId, NodeId}, Rt#ebt_rt.node_run_result).

get_node_run_result(Rt, TreeId, NodeId, Default) ->
    maps:get({TreeId, NodeId}, Rt#ebt_rt.node_run_result, Default).

clr_node_run_result(Rt, TreeId, NodeId) ->
    Rt1 = Rt#ebt_rt{node_run_result = maps:remove({TreeId, NodeId}, Rt#ebt_rt.node_run_result)},
    Rt1.

%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
assign_array(List, Index, Value) ->
    assign_array(List, Index, Value, 1, []).

assign_array([_ | T], Index, Value, Index, AccList) ->
    lists:reverse(AccList, [Value | T]);
assign_array([H | T], Index, Value, AccIndex, AccList) ->
    assign_array(T, Index, Value, AccIndex+1, [H | AccList]);
assign_array([], _Index, _Value, _AccIndex, AccList) ->
    lists:reverse(AccList).
