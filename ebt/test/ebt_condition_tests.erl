%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2022, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_condition_tests).
-author("z.hua").

-include_lib("eunit/include/eunit.hrl").

-include("ebt.hrl").

run_test_() ->
    ebt:init(fun generated_behaviors:find/1),

    Id1 = 'test_condition_1',
    Rt1 = do(Id1),

    Id2 = 'test_condition_2',
    Rt2 = do(Id2),

    Id3 = 'test_condition_3',
    Rt3 = do(Id3),

    Id4 = 'test_condition_4',
    Rt4 = do(Id4),

    Id5 = 'test_condition_5',
    Rt5 = do(Id5),

    Id6 = 'test_condition_6',
    Rt6 = do(Id6),

    Id7 = 'test_condition_7',
    Rt7 = do(Id7),

    Id8 = 'test_condition_8',
    Rt8 = do(Id8),

    [
        ?_assertEqual(?FAILURE, Rt1#ebt_rt.result)
        , ?_assertEqual([{Id1,0}], lists:reverse(Rt1#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt2#ebt_rt.result)
        , ?_assertEqual([{Id2,0}], lists:reverse(Rt2#ebt_rt.tracing))

        , ?_assertEqual(?FAILURE, Rt3#ebt_rt.result)
        , ?_assertEqual([{Id3,0}], lists:reverse(Rt3#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt4#ebt_rt.result)
        , ?_assertEqual([{Id4,0}], lists:reverse(Rt4#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt5#ebt_rt.result)
        , ?_assertEqual([{Id5,0}], lists:reverse(Rt5#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt6#ebt_rt.result)
        , ?_assertEqual([{Id6,0}], lists:reverse(Rt6#ebt_rt.tracing))

        , ?_assertEqual(?FAILURE, Rt7#ebt_rt.result)
        , ?_assertEqual([{Id7,0}], lists:reverse(Rt7#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt8#ebt_rt.result)
        , ?_assertEqual([{Id8,0}], lists:reverse(Rt8#ebt_rt.tracing))
    ].

do(TreeId) ->
    {ok, Ref} = ebt:new(TreeId),
    ebt:run(Ref),
    maps:get(Ref, (ebt_runtime:get_manager())#ebt_mgr.runtimes).
