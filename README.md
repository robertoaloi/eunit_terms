#eunit_terms

EUnit reports, stored as Erlang terms.

##Quick Start

Compile everything:

        erlc fact.erl fact_test.erl eunit_terms.erl

Generate a DETS table in the current directory. The table, by default named _results_, will contain the EUnit results, stored as Erlang terms. This might be useful to further process the results.

        erl
        > eunit:test([fact_test], [{report,{eunit_terms,[]}}]).
        All 3 tests passed.
        ok

Read the results:

        > {ok, Ref} = dets:open_file(results).
        {ok,#Ref<0.0.0.114>}
        > dets:lookup(Ref, testsuite).
        [{testsuite,<<"module 'fact_test'">>,8,<<>>,3,0,0,0,
            [{testcase,{fact_test,fact_zero_test,0,0},[],ok,0,<<>>},
             {testcase,{fact_test,fact_neg_test,0,0},[],ok,0,<<>>},
             {testcase,{fact_test,fact_pos_test,0,0},[],ok,0,<<>>}]}]

Specify a name for the DETS table:

        > eunit:test([fact_test], [{report,{eunit_terms,[{table, my_results}]}}]).

## A testsuite looks like this:

<pre>
-record(testcase, {
          name :: chars(),
          description :: chars(),
          result :: ok | {failed, tuple()} | {aborted, tuple()} | {skipped, tuple()},
          time :: integer(),
          output :: binary()
         }).
-record(testsuite, {
          name = <<>> :: binary(),
          time = 0 :: integer(),
          output = <<>> :: binary(),
          succeeded = 0 :: integer(),
          failed = 0 :: integer(),
          aborted = 0 :: integer(),
          skipped = 0 :: integer(),
          testcases = [] :: [#testcase{}]
         }).
</pre>
