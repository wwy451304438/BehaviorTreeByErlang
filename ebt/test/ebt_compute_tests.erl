%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2022, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_compute_tests).
-author("z.hua").

-include_lib("eunit/include/eunit.hrl").

-include("ebt.hrl").

run_test_() ->
    ebt:init(fun generated_behaviors:find/1),

    Id1 = 'test_compute_1',
    Rt1 = do(Id1),

    Id2 = 'test_compute_2',
    Rt2 = do(Id2),

    [
        ?_assertEqual(?SUCCESS, Rt1#ebt_rt.result)
        , ?_assertEqual([{Id1,0}], lists:reverse(Rt1#ebt_rt.tracing))
        , ?_assertEqual(3, my_agent:get_var(Rt1#ebt_rt.agent, 'Int'))

        ,?_assertEqual(?SUCCESS, Rt2#ebt_rt.result)
        , ?_assertEqual([{Id2,0}], lists:reverse(Rt2#ebt_rt.tracing))
        , ?_assertEqual(124, my_agent:get_var(Rt2#ebt_rt.agent, 'Int'))
    ].

do(TreeId) ->
    {ok, Ref} = ebt:new(TreeId),
    ebt:run(Ref),
    maps:get(Ref, (ebt_runtime:get_manager())#ebt_mgr.runtimes).
