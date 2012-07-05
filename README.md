#eunit_terms

EUnit reports, as Erlang terms.

# Quick Start

Compile everything:

<code>
        erlc fact.erl fact_test.erl eunit_terms.erl
</code>

Generate a DETS table in the current directory. The table, by default named _results_, will contain the EUnit results, stored as Erlang terms, for further processing:

<code>
        erl
        > eunit:test([fact_test], [{report,{eunit_terms,[]}}]).
        All 3 tests passed.
        ok
</code>

Read the results:

<code>
        > {ok, Ref} = dets:open_file(results).
        {ok,#Ref<0.0.0.114>}
        > dets:lookup(Ref, testsuite).
        [{testsuite,<<"module 'fact_test'">>,8,<<>>,3,0,0,0,
            [{testcase,"fact_test:fact_zero_test/0_0",[],ok,0,<<>>},
             {testcase,"fact_test:fact_neg_test/0_0",[],ok,0,<<>>},
             {testcase,"fact_test:fact_pos_test/0_0",[],ok,0,<<>>}]}]
</code>

Specify a name for the DETS table:

<code>
        > eunit:test([fact_test], [{report,{eunit_terms,[{table, my_results}]}}]).
</code>

# A teststuite looks like this:

<code>
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
</code>