-module(fact_test).

-include_lib("eunit/include/eunit.hrl").

fact_pos_test() ->
    ?assertEqual(120, fact:fact(5)).

fact_neg_test() ->
    ?assertException(error, function_clause, fact:fact(-3)).

fact_zero_test() ->
    ?assertEqual(1, fact:fact(0)).

