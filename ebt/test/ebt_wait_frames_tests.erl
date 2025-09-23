%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2022, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_wait_frames_tests).
-author("z.hua").

-include_lib("eunit/include/eunit.hrl").

-include("ebt.hrl").

run_test_() ->
    ebt:init(fun generated_behaviors:find/1),

    Id1 = 'test_wait_frames_1',
    {ok, Ref1} = ebt:new(Id1),
    Rt1_1 = do(Ref1),
    Rt1_2 = do(Ref1),
    Rt1_3 = do(Ref1),

    Id2 = 'test_wait_frames_2',
    {ok, Ref2} = ebt:new(Id2),
    Rt2_1 = do(Ref2),
    Rt2_2 = do(Ref2),
    Rt2_3 = do(Ref2),

    [
        ?_assertEqual(?RUNNING, Rt1_1#ebt_rt.result)
        , ?_assertEqual([{Id1,0}], lists:reverse(Rt1_1#ebt_rt.tracing))

        , ?_assertEqual(?RUNNING, Rt1_2#ebt_rt.result)
        , ?_assertEqual([{Id1,0},{Id1,0}], lists:reverse(Rt1_2#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt1_3#ebt_rt.result)
        , ?_assertEqual([{Id1,0},{Id1,0},{Id1,0}], lists:reverse(Rt1_3#ebt_rt.tracing))

        , ?_assertEqual(?RUNNING, Rt2_1#ebt_rt.result)
        , ?_assertEqual([{Id2,0}], lists:reverse(Rt2_1#ebt_rt.tracing))

        , ?_assertEqual(?RUNNING, Rt2_2#ebt_rt.result)
        , ?_assertEqual([{Id2,0},{Id2,0}], lists:reverse(Rt2_2#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt2_3#ebt_rt.result)
        , ?_assertEqual([{Id2,0},{Id2,0},{Id2,0}], lists:reverse(Rt2_3#ebt_rt.tracing))
    ].

do(Ref) ->
    ebt:run(Ref),
    maps:get(Ref, (ebt_runtime:get_manager())#ebt_mgr.runtimes).
