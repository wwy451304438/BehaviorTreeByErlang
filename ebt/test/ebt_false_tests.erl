%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2022, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_false_tests).
-author("z.hua").

-include_lib("eunit/include/eunit.hrl").

-include("ebt.hrl").

run_test_() ->
    ebt:init(fun generated_behaviors:find/1),

    Id1 = 'test_false',
    Rt1 = do(Id1),

    [
        ?_assertEqual(?FAILURE, Rt1#ebt_rt.result)
        , ?_assertEqual([{Id1,0}], lists:reverse(Rt1#ebt_rt.tracing))
    ].

do(TreeId) ->
    {ok, Ref} = ebt:new(TreeId),
    ebt:run(Ref),
    maps:get(Ref, (ebt_runtime:get_manager())#ebt_mgr.runtimes).
