%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2021, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt).
-author("z.hua").

-include("ebt.hrl").

%% 行为树运行id
-type tree_ref() :: integer().

%% 行为树配置id
-type tree_id() :: integer().

%% 节点id
-type node_id() :: integer().

%% 事件
-type event() :: atom().

%% 节点运行结果
-type result() :: ?SUCCESS | ?FAILURE | ?RUNNING.

-export_type([tree_ref/0, tree_id/0, node_id/0, event/0, result/0]).

%%-----------------------------------------------------------------------------
%% API Functions
%%-----------------------------------------------------------------------------
-export([
    init/2,
    new/1,
    run/1,
    event/4,
    abort/1
]).

%%-----------------------------------------------
%% @doc 初始化行为树管理器
-spec init(GetTree, Logger) -> ok when
    GetTree :: function(), % func(TreeId) -> #ebt_tree{} end.
    Logger  :: function(). % func(Fmt, Args) -> any() end.
%%-----------------------------------------------
init(GetTree, Logger) ->
    ebt_runtime:set_manager(#ebt_mgr{
        ref_id   = 1,
        runtimes = #{},
        get_tree = GetTree,
        logger   = Logger
    }).

%%-----------------------------------------------
%% @doc 创建运行时行为树
-spec new(TreeId) -> Result when
    TreeId :: tree_id(),
    Result :: {ok, tree_ref()} | {error, Reason::any()}.
%%-----------------------------------------------
new(TreeId) ->
    Mgr  = #ebt_mgr{ref_id = TreeRef} = ebt_runtime:get_manager(),
    Tree = ebt_runtime:get_tree(TreeId),
    Rt = #ebt_rt{
        ref       = TreeRef,
        agent     = Tree#ebt_tree.agent,
        tree_id   = TreeId,
        node_path = [],
        tree_path = [],
        status    = #{}
    },
    ebt_runtime:set_manager(Mgr#ebt_mgr{
        ref_id   = TreeRef + 1,
        runtimes = maps:put(TreeRef, Rt, Mgr#ebt_mgr.runtimes)
    }),
    {ok, TreeRef}.

%%-----------------------------------------------
%% @doc 运行行为树
-spec run(TreeRef) -> Result when
    TreeRef :: tree_ref(),
    Result  :: ok | {error, Reason::any()}.
%%-----------------------------------------------
run(TreeRef) ->
    #ebt_mgr{runtimes = Runtimes} = ebt_runtime:get_manager(),
    case maps:find(TreeRef, Runtimes) of
        {ok, Rt} ->
            Tree = ebt_runtime:get_tree(Rt#ebt_rt.tree_id),
            Rt2  = ebt_behavior:ahead(Rt, Tree, Tree#ebt_tree.entry, -1),
            run_after(Rt2);
        error ->
            {error, {not_running, TreeRef}}
    end.


%%-----------------------------------------------
%% @doc 触发事件
-spec event(TreeRef, Event, EvtArgs, Before) -> Result when
    TreeRef :: tree_ref(),
    Event   :: event(),
    EvtArgs :: [any()],
    Before  :: fun(),
    Result  :: ok | {error, Reason::any()}.
%%-----------------------------------------------
event(TreeRef, Event, EvtArgs, Before) ->
    Mgr = ebt_runtime:get_manager(),
    case maps:find(TreeRef, Mgr#ebt_mgr.runtimes) of
        {ok, Rt} ->
            Tree = ebt_runtime:get_tree(Rt#ebt_rt.tree_id),
            case lists:keyfind(Event, #ebt_event.task, Tree#ebt_tree.events) of
                false ->
                    ok;
                EbtEvent ->
                    Tree = ebt_runtime:get_tree(Rt#ebt_rt.tree_id),
                    run_event(Rt, Tree, EbtEvent, EvtArgs, Before)
            end;
        error ->
            {error, {runtime_tree_not_exist, TreeRef}}
    end.

%%-----------------------------------------------
%% @doc 销毁运行时行为树
-spec abort(TreeRef) -> Result when
    TreeRef :: tree_ref(),
    Result  :: ok | {error, Reason::any()}.
%%-----------------------------------------------
abort(TreeRef) ->
    Mgr = #ebt_mgr{runtimes = Runtimes} = ebt_runtime:get_manager(),
    case maps:is_key(TreeRef, Runtimes) of
        true  ->
            ebt_runtime:set_manager(Mgr#ebt_mgr{
                runtimes = maps:remove(TreeRef, Runtimes)
            }),
            ok;
        false ->
            {error, {runtime_tree_not_exist, TreeRef}}
    end.

%%-----------------------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------------------
run_event(Rt, Tree, EbtEvent, EvtArgs, Before) ->
    #ebt_rt{already_trigger_event = AlreadyTriggerEvent} = Rt,
    #ebt_event{id = EventId, once = Once, mode = Mode, tree = Subtree} = EbtEvent,
    case Once andalso lists:member(EventId, Rt#ebt_rt.already_trigger_event) of
        true  ->
            ok;
        false ->
            ?__if(is_function(Before, 0), Before(), skip),
            AlreadyTriggerEvent1 = lists:uniq([EventId | AlreadyTriggerEvent]),
            Rt1 = Rt#ebt_rt{params = EvtArgs},
            Rt2 = Rt1#ebt_rt{already_trigger_event = AlreadyTriggerEvent1},
            Rt3 = ebt_runtime:run_subtree(Rt2, Tree, Subtree, Mode == 'Transfer'),
            run_after(Rt3)
    end.


run_after(Rt) ->
    Mgr = #ebt_mgr{runtimes = Runtimes} = ebt_runtime:get_manager(),
    ebt_runtime:set_manager(Mgr#ebt_mgr{
        runtimes = maps:put(Rt#ebt_rt.ref, Rt, Runtimes)
    }),
    ok.
