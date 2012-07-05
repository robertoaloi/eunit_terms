%% This library is free software; you can redistribute it and/or modify
%% it under the terms of the GNU Lesser General Public License as
%% published by the Free Software Foundation; either version 2 of the
%% License, or (at your option) any later version.
%%
%% This library is distributed in the hope that it will be useful, but
%% WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%%
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library; if not, write to the Free Software
%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
%% USA
%%
%% $Id: $
%%
%% @author Roberto Aloi <roberto@erlang-solutions.com>
%% @copyright 2011 Erlang Solutions
%% @see eunit
%% @doc Based on initial code from Paul Guyot and Mickael Remond (eunit_surefire).

-module(eunit_terms).

-behaviour(eunit_listener).

-include_lib("eunit/include/eunit.hrl").

-export([start/0, start/1]).

-export([init/1,
         handle_begin/3,
         handle_end/3,
         handle_cancel/3,
         terminate/2]).

%% ============================================================================
%% TYPES
%% ============================================================================
-type(chars() :: [char() | any()]). % chars()

%% ============================================================================
%% MACROS
%% ============================================================================
-define(DEFAULT_TABLE, "results").

%% ============================================================================
%% RECORDS
%% ============================================================================
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
-record(state, {
          verbose = false,
          table = ?DEFAULT_TABLE,
          testsuite = #testsuite{}
         }).

start() ->
    start([]).

start(Options) ->
    eunit_listener:start(?MODULE, Options).

init(Options) ->
    Table = proplists:get_value(table, Options, ?DEFAULT_TABLE),
    {ok, Table} = dets:open_file(Table, []),
    St = #state{verbose = proplists:get_bool(verbose, Options),
                table = Table,
                testsuite = #testsuite{}},
    receive
        {start, _Reference} ->
            St
    end.

terminate({ok, _Data}, #state{testsuite = TS} = St) ->
    Table = St#state.table,
    ok = dets:insert(Table, TS),
    ok = dets:close(Table);
terminate({error, Reason}, _St) ->
    io:fwrite("Internal error: ~P.\n", [Reason, 25]),
    sync_end(error).

sync_end(Result) ->
    receive
	{stop, Reference, ReplyTo} ->
	    ReplyTo ! {result, Reference, Result},
	    ok
    end.

handle_begin(group, Data, St) ->
    NewId = proplists:get_value(id, Data),
    case NewId of
	[] ->
	    St;
	[_GroupId] ->
	    Desc = proplists:get_value(desc, Data),
	    TestSuite = St#state.testsuite,
	    NewTestSuite = TestSuite#testsuite{name = Desc},
	    St#state{testsuite=NewTestSuite};
	%% Surefire format is not hierarchic: Ignore subgroups:
	_ ->
	    St
    end;
handle_begin(test, _Data, St) ->
    St.
handle_end(group, Data, St) ->
    %% Retrieve existing test suite:
    case proplists:get_value(id, Data) of
	[] ->
	    St;
	[_GroupId|_] ->
	    TestSuite = St#state.testsuite,

	    %% Update TestSuite data:
	    Time = proplists:get_value(time, Data),
	    Output = proplists:get_value(output, Data),
	    NewTestSuite = TestSuite#testsuite{ time = Time, output = Output },
	    St#state{testsuite=NewTestSuite}
    end;
handle_end(test, Data, St) ->
    %% Retrieve existing test suite:
    TestSuite = St#state.testsuite,

    %% Create test case:
    Name = format_name(proplists:get_value(source, Data),
                       proplists:get_value(line, Data)),
    Desc = format_desc(proplists:get_value(desc, Data)),
    Result = proplists:get_value(status, Data),
    Time = proplists:get_value(time, Data),
    Output = proplists:get_value(output, Data),
    TestCase = #testcase{name = Name, description = Desc,
			 time = Time,output = Output},
    NewTestSuite = add_testcase_to_testsuite(Result, TestCase, TestSuite),
    St#state{testsuite=NewTestSuite}.

%% Cancel group does not give information on the individual cancelled test case
%% We ignore this event
handle_cancel(group, _Data, St) ->
    St;
handle_cancel(test, Data, St) ->
    %% Retrieve existing test suite:
    TestSuite = St#state.testsuite,

    %% Create test case:
    Name = format_name(proplists:get_value(source, Data),
		       proplists:get_value(line, Data)),
    Desc = format_desc(proplists:get_value(desc, Data)),
    Reason = proplists:get_value(reason, Data),
    TestCase = #testcase{
      name = Name, description = Desc,
      result = {skipped, Reason}, time = 0,
      output = <<>>},
    NewTestSuite = TestSuite#testsuite{
		     skipped = TestSuite#testsuite.skipped+1,
		     testcases=[TestCase|TestSuite#testsuite.testcases] },
    St#state{testsuite=NewTestSuite}.

format_name({Module, Function, Arity}, Line) ->
    lists:flatten([atom_to_list(Module), ":", atom_to_list(Function), "/",
		   integer_to_list(Arity), "_", integer_to_list(Line)]).
format_desc(undefined) ->
    "";
format_desc(Desc) when is_binary(Desc) ->
    binary_to_list(Desc);
format_desc(Desc) when is_list(Desc) ->
    Desc.

%% Add testcase to testsuite depending on the result of the test.
add_testcase_to_testsuite(ok, TestCaseTmp, TestSuite) ->
    TestCase = TestCaseTmp#testcase{ result = ok },
    TestSuite#testsuite{
      succeeded = TestSuite#testsuite.succeeded+1,
      testcases=[TestCase|TestSuite#testsuite.testcases] };
add_testcase_to_testsuite({error, Exception}, TestCaseTmp, TestSuite) ->
    case Exception of
	{error,{AssertionException,_},_} when
              AssertionException == assertion_failed;
              AssertionException == assertMatch_failed;
              AssertionException == assertEqual_failed;
              AssertionException == assertException_failed;
              AssertionException == assertCmd_failed;
              AssertionException == assertCmdOutput_failed
              ->
	    TestCase = TestCaseTmp#testcase{ result = {failed, Exception} },
	    TestSuite#testsuite{
	      failed = TestSuite#testsuite.failed+1,
	      testcases = [TestCase|TestSuite#testsuite.testcases] };
	_ ->
	    TestCase = TestCaseTmp#testcase{ result = {aborted, Exception} },
	    TestSuite#testsuite{
	      aborted = TestSuite#testsuite.aborted+1,
	      testcases = [TestCase|TestSuite#testsuite.testcases] }
    end.
