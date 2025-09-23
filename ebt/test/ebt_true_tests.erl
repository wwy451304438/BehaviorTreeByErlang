%%%-------------------------------------------------------------------
%%% @author z.hua
%%% @copyright (C) 2022, <ShiYue>
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(ebt_true_tests).
-author("z.hua").

-include_lib("eunit/include/eunit.hrl").

-include("ebt.hrl").

run_test_() ->
    ebt:init(fun generated_behaviors:find/1),

    Id1 = 'test_true',
    Rt1 = do(Id1),

    [
        ?_assertEqual(?SUCCESS, Rt1#ebt_rt.result)
        , ?_assertEqual([{Id1,0}], lists:reverse(Rt1#ebt_rt.tracing))
    ].

do(TreeId) ->
    {ok, Ref} = ebt:new(TreeId),
    ebt:run(Ref),
    maps:get(Ref, (ebt_runtime:get_manager())#ebt_mgr.runtimes).
