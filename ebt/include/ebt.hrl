-ifndef(EBT_HRL).
-define(EBT_HRL, true).

-define(__nil, undefined).

-define(__if(__Expr, __T, __F), case (__Expr) of true -> (__T); false -> (__F) end).

%% 节点运行结果
-define(SUCCESS, 'success'). % 节点执行成功
-define(FAILURE, 'failure'). % 节点执行失败
-define(RUNNING, 'running'). % 节点尚未执行完毕, 下次运行行为树时将从此节点继续运行
-define(INVALID, 'invalid'). % 非法结果

-define(is_success(Result), (Result == ?SUCCESS)).
-define(is_failure(Result), (Result == ?FAILURE)).
-define(is_running(Result), (Result == ?RUNNING)).
-define(is_invalid(Result), (Result == ?INVALID)).

-define(run_finish(Result), (Result /= ?RUNNING)).

-type run_result() :: ?SUCCESS | ?FAILURE | ?RUNNING | ?INVALID.

-define(node_ahead_enter_phase, enter).     % 首次进入阶段
-define(node_ahead_update_phase, update).   % 更新执行阶段
-define(node_ahead_stop_phase, stop).       % 停止阶段

-type node_ahead_phase() :: ?node_ahead_enter_phase | ?node_ahead_update_phase | ?node_ahead_stop_phase.

-export_type([node_ahead_phase/0]).


%% 前置条件
-record(ebt_precondition, {
    id

    % 执行时机
    % enter  : 进入节点时检查;
    % update : 每次更新时检查
    % both
    , phase  :: enter | update | both

    % 多个前置是“与（and）”还是“或（or）”的运算关系
    , is_and :: boolean()

    % 条件
    , check
}).

%% 后置动作
-record(ebt_effector, {
    id

    % 执行时机
    % success : 节点执行成功后执行
    % failure : 节点执行失败后执行
    % both
    , phase

    % 动作
    , action
}).

%% 事件
-record(ebt_event, {
    id

    % 事件任务
    , task

    % 事件是否只触发一次就不再起作用
    , once

    % 触发模式，事件触发后对当前行为树的影响以及被触发的子树结束时应该如何恢复
    % transfer : 当子树结束时，当前行为树被中断和重置，该子树将被设置为当前行为树
    % return   : 当子树结束时，返回控制到之前打断的地方继续执行
    , mode

    % 事件子树
    , tree
}).

%% 节点配置信息
-record(ebt_node, {
    % 节点id
    id        :: ebt:node_id(),

    % 节点执行模块
    executor  :: module(),

    % 子节点id列表
    children  :: [ebt:node_id()],

    % 节点属性
    property  :: map(),

    % 中断条件
    interrupt :: undefined | #ebt_node{},

    % 前置条件
    preconditions  :: [#ebt_precondition{}],

    % 后置效果
    effectors :: [#ebt_effector{}],

    % 事件
    events :: [#ebt_event{}],

    % 装饰节点是否在子节点结束后运行
    decorator_when_child_end :: boolean()
}).

%% 行为树配置信息
-record(ebt_tree, {
    % 行为树id
    id    :: integer(),

    agent :: any(),

    % 所有节点
    nodes :: #{ebt:node_id() => #ebt_node{}},

    % 入口节点
    entry :: ebt:node_id(),

    % 行为树挂载的事件
    events :: [ebt:node_id()]
}).

%% 行为树运行时信息
-record(ebt_rt, {
    % 行为树运行时引用
    ref :: ebt:tree_ref(),

    % 运行行为树的代理
    agent :: any(),

    % 事件参数
    params :: [any()],

    % 行为树id
    tree_id :: ebt:tree_id(),

    % 节点路径
    node_path :: [ebt:node_id()],

    % 行为树路径
    tree_path :: [ebt:tree_id()],

    % 运行结果
    result :: ebt:result(),

    % 节点状态
    status :: #{ebt:node_id() => map()},

    % 执行路径
    tracing = [],

    % 节点运行结果
    node_run_result = #{} :: #{NodeId :: integer() => Result :: run_result()},

    % 已经触发的事件
    already_trigger_event = []
}).

%% 行为树管理器
-record(ebt_mgr, {
    % 运行时id
    ref_id   :: ebt:tree_ref(),

    % 运行时信息
    runtimes :: #{ebt:tree_ref() => #ebt_rt{}},

    % 获取行为树
    get_tree :: function(),

    % 日志
    logger :: function()
}).

-endif.
