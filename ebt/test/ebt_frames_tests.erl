%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2022, <ShiYue>
%%% @doc
%%%
%%% @end
%%% Created : 22. 11月 2022 16:42
%%%-------------------------------------------------------------------
-module(ebt_frames_tests).
-author("z.hua").

-include_lib("eunit/include/eunit.hrl").

-include("ebt.hrl").

run_test_() ->
    ebt:init(fun generated_behaviors:find/1),

    Id1 = 'test_frames',
    {ok, Ref} = ebt:new(Id1),
    Rt1 = do(Ref),
    Rt2 = do(Ref),
    Rt3 = do(Ref),

    [
        ?_assertEqual(?RUNNING, Rt1#ebt_rt.result)
        , ?_assertEqual([{Id1,0},{Id1,1},{Id1,0}], lists:reverse(Rt1#ebt_rt.tracing))

        , ?_assertEqual(?RUNNING, Rt2#ebt_rt.result)
        , ?_assertEqual([{Id1,0},{Id1,1},{Id1,0},{Id1,0},{Id1,1},{Id1,0}], lists:reverse(Rt2#ebt_rt.tracing))

        , ?_assertEqual(?SUCCESS, Rt3#ebt_rt.result)
        , ?_assertEqual([{Id1,0},{Id1,1},{Id1,0},{Id1,0},{Id1,1},{Id1,0},{Id1,0},{Id1,1},{Id1,0}], lists:reverse(Rt3#ebt_rt.tracing))
    ].

do(Ref) ->
    ebt:run(Ref),
    maps:get(Ref, (ebt_runtime:get_manager())#ebt_mgr.runtimes).
