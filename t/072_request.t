use strict;
use warnings;

use Data::Dumper;
local $Data::Dumper::Indent = 1;

### Testing invalid inputs

use Test::More tests => 89;

BEGIN { use_ok 'RPC::ExtDirect::Request'; }

# Test modules are so simple they can't fail
use lib 't/lib';
use RPC::ExtDirect::Test::Foo;
use RPC::ExtDirect::Test::Bar;
use RPC::ExtDirect::Test::Qux;
use RPC::ExtDirect::Test::PollProvider;

my $tests = eval do { local $/; <DATA>; }       ## no critic
    or die "Can't eval test data: $@";

for my $test ( @$tests ) {
    # Unpack variables
    my ($name, $data, $expected_ran, $expected_result, $debug,
        $run_twice, $isa)
        = @$test{ qw(name data ran_ok result debug run_twice isa)
                };

    # Set debug flag according to test
    local $RPC::ExtDirect::Request::DEBUG = $debug;

    # Try to create object
    my $request = eval { RPC::ExtDirect::Request->new($data) };

    is     $@,       '', "$name new() eval $@";
    ok     $request,     "$name new() object created";
    isa_ok $request, $isa;

    # Try to run method
    my $ran_ok = eval { $request->run() };

    is $@,      '',            "$name run() eval $@";
    is $ran_ok, $expected_ran, "$name run() no error";

    # Try to run method second time, no result checks this time
    $ran_ok = eval { $request->run() } if $run_twice;

    # Try to get results
    my $result = eval { $request->result() };

    is        $@,      '',               "$name result() eval $@";
    ok        $result,                   "$name result() not empty";
    is_deeply $result, $expected_result, "$name result() deep"
        or print Data::Dumper->Dump( [$result], ['result'] );
};

__DATA__
[
    # Null input, debug off
    {
        name   => 'Failure 1, debug off', debug  => 0,
        data   => undef,                      ran_ok => '',
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'ExtDirect',
                    message => 'An error has occured while processing '.
                               'request', },
    },
    # Action not found, debug off
    {
        name   => 'Failure 2, debug off', debug  => 0, ran_ok => '',
        data   => { action  => 'Nonexistent', method => 'nonexistent',
                    type    => 'rpc',         tid    => 111,
                    data    => [], },
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception', where   => 'ExtDirect',
                    message => 'An error has occured while processing '.
                               'request', },
    },
    # Null input, debug on
    {
        name   => 'Null input, debug on', debug  => 1,
        data   => undef,        ran_ok => '',
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->new',
                    message => 'ExtDirect input error: invalid input', },
    },
    # Invalid input 1, debug on
    {
        name   => 'Invalid input 1, debug on', debug => 1, ran_ok => '',
        data   => { action  => '', method => 'foo', type => 'rpc',
                    tid     => 1, data => [], },
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->new',
                    message => 'ExtDirect action (class name) required' },
    },
    # Invalid input 2, debug on
    {
        name   => 'Invalid input 2, debug on', debug => 1, ran_ok => '',
        data   => { action  => 'Some', method => '', type => 'rpc',
                    tid     => 2, data => [], },
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->new',
                    message => 'ExtDirect method name required' },
    },
    # Action not found, debug on
    {
        name   => 'Action not found, debug on', debug  => 1, ran_ok => '',
        data   => { action  => 'None',          method => 'nonexistent',
                    type    => 'rpc',           tid    => 111,
                    data    => [], },
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->new',
                    message => 'ExtDirect action or method not found' },
    },
    # Not enough arguments
    {
        name   => 'Not enough args, debug on', debug => 1, ran_ok => '',
        data   => { action  => 'Qux', method => 'bar_foo', tid    => 222,
                    type    => 'rpc', data   => [ 1, 2, 3 ], },
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->_check_arguments',
                    message => 'ExtDirect method Qux.bar_foo '.
                               'needs 4 arguments instead of 3', },
    },
    # Tried to run method twice
    {
        name   => 'Try to run twice, debug on', debug => 1, ran_ok => 1,
        data   => { action  => 'Qux', method => 'foo_foo', tid => 333,
                    type    => 'rpc', data   => [ 123 ], },
        isa    => 'RPC::ExtDirect::Request',
        run_twice => 1,
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->run',
                    message => "ExtDirect request can't be run more than ".
                               "once", },
    },
    # Method call failed
    {
        name   => 'Method failed, debug on', debug => 1, ran_ok => '',
        data   => { action  => 'Qux', method => 'bar_foo', tid => 444,
                    type    => 'rpc', data => [ 1, 2, 3, 4 ], },
        isa    => 'RPC::ExtDirect::Request',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Test::Qux->bar_foo',
                    message => "ExtDirect request failed: 'bar foo!'", },
    },
    # Form handler called directly
    {
        name   => 'Form handler called directly', debug => 1, ran_ok => '',
        data   => { action => 'Bar', method => 'bar_baz', tid => 555,
                    type => 'rpc', data => {}, },
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->_check_arguments',
                    message => "ExtDirect formHandler method ".
                               "Bar.bar_baz should only be called ".
                               "with form submits", },
    },
    # Poll handler called directly
    {
        name   => 'Poll handler called directly', debug => 1, ran_ok => '',
        data   => { action => 'PollProvider', method => 'foo', tid => 666,
                    type => 'rpc', data => [], },
        isa    => 'RPC::ExtDirect::Exception',
        result => { type    => 'exception',
                    where   => 'RPC::ExtDirect::Request->_check_arguments',
                    message => "ExtDirect pollHandler method ".
                               "PollProvider.foo should not ".
                               "be called directly", },
    },
]
