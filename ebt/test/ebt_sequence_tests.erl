%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2022, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_sequence_tests).
-author("z.hua").

-include_lib("eunit/include/eunit.hrl").

-include("ebt.hrl").

run_test_() ->
    ebt:init(fun generated_behaviors:find/1),

    Id1 = 'test_sequence_1',
    Rt1 = do(Id1),

    Id2 = 'test_sequence_2',
    Rt2 = do(Id2),

    Id3 = 'test_sequence_3',
    Rt3 = do(Id3),

    Id4 = 'test_sequence_4',
    Rt4 = do(Id4),

    [
        ?_assertEqual(?FAILURE, Rt1#ebt_rt.result)
        , ?_assertEqual([{Id1,0},{Id1,1},{Id1,0},{Id1,2},{Id1,0}], lists:reverse(Rt1#ebt_rt.tracing))

        , ?_assertEqual(?FAILURE, Rt2#ebt_rt.result)
        , ?_assertEqual([{Id2,0},{Id2,1},{Id2,0}], lists:reverse(Rt2#ebt_rt.tracing))

        , ?_assertEqual(?FAILURE, Rt3#ebt_rt.result)
        , ?_assertEqual([{Id3,0},{Id3,1},{Id3,0}], lists:reverse(Rt3#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt4#ebt_rt.result)
        , ?_assertEqual([{Id4,0},{Id4,1},{Id4,0},{Id4,2},{Id4,0}], lists:reverse(Rt4#ebt_rt.tracing))
    ].

do(TreeId) ->
    {ok, Ref} = ebt:new(TreeId),
    ebt:run(Ref),
    maps:get(Ref, (ebt_runtime:get_manager())#ebt_mgr.runtimes).
