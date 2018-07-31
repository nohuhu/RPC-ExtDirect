use strict;
use warnings FATAL => 'all';

use RPC::ExtDirect::Test::Util;
use RPC::ExtDirect::Config;
use RPC::ExtDirect;

### Testing successful requests

use Test::More tests => 84;

use RPC::ExtDirect::Request;

use RPC::ExtDirect::Test::Pkg::Foo;
use RPC::ExtDirect::Test::Pkg::Bar;
use RPC::ExtDirect::Test::Pkg::Qux;

my %only_tests = map { $_ => 1 } @ARGV;

my $tests = eval do { local $/; <DATA>; }       ## no critic
    or die "Can't eval test data: $@";

for my $test ( @$tests ) {
    my ($name, $data, $expected_ran, $expected_result, $debug,
        $run_twice, $isa, $class)
        = @$test{ qw(name data ran_ok result debug run_twice isa class)
                };
    
    next if %only_tests and not $only_tests{$name};

    # Set debug flag according to test
    $data->{config} = RPC::ExtDirect::Config->new( debug_request => $debug, );
    $data->{api}    = RPC::ExtDirect->get_api();
    
    $class ||= 'RPC::ExtDirect::Request';
    
    eval "require $class";

    my $request = eval { $class->new($data) };

    is     $@,       '', "$name new() eval $@";
    ok     $request,     "$name new() object created";
    ref_ok $request, $isa;

    my $ran_ok = eval { $request->run() };

    is $@,      '',            "$name run() eval $@";
    is $ran_ok, $expected_ran, "$name run() no error";

    # Try to run method second time, no result checks this time
    $ran_ok = eval { $request->run() } if $run_twice;

    my $result = eval { $request->result() };

    is      $@,      '',               "$name result() eval $@";
    is_deep $result, $expected_result, "$name result() deep";
};

__DATA__
[
    # Numbered one argument with scalar result
    {
        name   => 'Foo->foo_foo, 1 arg', debug => 1, ran_ok => 1,
        data   => { action => 'Foo', method => 'foo_foo',
                    tid => 1, data => [ 1 ], type => 'rpc' },
        isa    => 'RPC::ExtDirect::Request',
        result => { type   => 'rpc', tid => 1, action => 'Foo',
                    method => 'foo_foo', result => "foo! '1'", },
    },
    # Numbered two arguments with arrayref result
    {
        name   => 'Foo->foo_bar, 2 args', debug => 1, ran_ok => 1,
        data   => { action => 'Foo', method => 'foo_bar',
                    tid => 2, data => [ 1234, 4321 ], type => 'rpc', },
        isa    => 'RPC::ExtDirect::Request',
        result => { type   => 'rpc', tid => 2,
                    action => 'Foo', method => 'foo_bar',
                    result => [ 'foo! bar!', 1234, 4321 ], },
    },
    # Named arguments, hashref result
    {
        name   => 'Foo->foo_baz, 3 args', debug => 1, ran_ok => 1,
        data   => { action => 'Foo', method => 'foo_baz',
                    tid => 3, type => 'rpc',
                    data => { foo => 111, bar => 222, baz => 333 }, },
        isa    => 'RPC::ExtDirect::Request',
        result => { type   => 'rpc', tid => 3,
                    action => 'Foo', method => 'foo_baz',
                    result => { msg  => 'foo! bar! baz!',
                                foo => 111, bar => 222, baz => 333 }, },
    },
    # Check if we're actually passing no more than defined numbered args
    {
        name   => 'Check number of args', ran_ok => 1, debug => 1,
        data   => { action => 'Qux', method => 'bar_bar', tid => 555,
                    type   => 'rpc', data => [ 1, 2, 3, 4, 5, 6, 7 ], },
        isa    => 'RPC::ExtDirect::Request',
        result => { type   => 'rpc', tid => 555, action => 'Qux',
                    method => 'bar_bar', result => 5, # Number of args def-d
                  },
    },
    # Check that only defined named parameters are passed
    {
        name   => 'Check named args', debug => 1, ran_ok => 1,
        data   => { action => 'Foo', method => 'foo_baz',
                    tid => 4, type => 'rpc',
                    data => { foo => 111, bar => [ '222?', '222!' ],
                              baz => 333,
                              qux => 'qux! qux!', blargh => 'phew',
                              splurge => 'choo-choo' }, },
        isa    => 'RPC::ExtDirect::Request',
        result => { type   => 'rpc', tid => 4,
                    action => 'Foo', method => 'foo_baz',
                    result => { msg  => 'foo! bar! baz!', foo => 111,
                                bar => [ '222?', '222!' ], baz => 333 }, },
    },
    # Form handler call, no upload
    {
        name   => 'Form call, no uploads', debug => 1, ran_ok => 1,
        data   => { action => '/something.cgi', method => 'POST',
                    extAction => 'Bar', extMethod => 'bar_baz',
                    extTID => 6, field1 => 'foo', field2 => 'bar', },
        isa    => 'RPC::ExtDirect::Request',
        result => { type => 'rpc', tid => 6, action => 'Bar',
                    method => 'bar_baz',
                    result => { field1 => 'foo', field2 => 'bar', }, },
    },
    # Form handler call, one file "upload"
    {
        name   => 'Form call, one upload', debug => 1, ran_ok => 1,
        data   => { action => '/router.cgi', method => 'POST',
                    extAction => 'Bar', extMethod => 'bar_baz',
                    extTID => 7, foo_field => 'foo', bar_field => 'bar',
                    extUpload => 'true',
                    _uploads => [{ basename => 'foo.txt',
                        type => 'text/plain', handle => {},     # dummy
                        filename => 'C:\Users\nohuhu\foo.txt',
                        path => '/tmp/cgi-upload/foo.txt', size => 123 }],
                  },
        isa    => 'RPC::ExtDirect::Request',
        result => { type => 'rpc', tid => 7, action => 'Bar',
                    method => 'bar_baz',
                    result => { foo_field => 'foo', bar_field => 'bar',
                                upload_response =>
                                "The following files were processed:\n".
                                "foo.txt text/plain 123\n",
                              },
                  },
    },
    # Form handler call, multiple uploads
    {
        name   => 'Form call, multi uploads', debug => 1, ran_ok => 1,
        data   => { action => '/router_action', method => 'POST',
                    extAction => 'Bar', extMethod => 'bar_baz',
                    extTID => 8, field => 'value', extUpload => 'true',
                    _uploads => [
                        { basename => 'bar.jpg', handle => {},
                          type => 'image/jpeg', filename => 'bar.jpg',
                          path => 'C:\Windows\tmp\bar.jpg', size => 123123, },
                        { basename => 'qux.png', handle => {},
                          type => 'image/png', filename => '/tmp/qux.png',
                          path => 'C:\Windows\tmp\qux.png', size => 54321, },
                        { basename => 'script.js', handle => undef,
                          type => 'application/javascript', size => 1000,
                          filename => '/Users/nohuhu/Documents/script.js',
                          path => 'C:\Windows\tmp\script.js', }, ],
                  },
        isa    => 'RPC::ExtDirect::Request',
        result => {
            type => 'rpc', tid => 8, action => 'Bar', method => 'bar_baz',
            result => { field => 'value', upload_response =>
                        "The following files were processed:\n".
                        "bar.jpg image/jpeg 123123\n".
                        "qux.png image/png 54321\n".
                        "script.js application/javascript 1000\n",
            },
        },
    },
    
    {
        name => 'JSON-RPC with no arguments', debug => 1, ran_ok => 1,
        class => 'RPC::ExtDirect::Request::JsonRpc',
        data => {
            jsonrpc => '2.0', method => 'Foo.foo_zero', id => "foo",
        },
        isa => 'RPC::ExtDirect::Request::JsonRpc',
        result => {
            jsonrpc => '2.0', id => "foo", result => ['RPC::ExtDirect::Test::Pkg::Foo'],
        },
    },
    
    {
        name => 'JSON-RPC with ordered arguments', debug => 1, ran_ok => 1,
        class => 'RPC::ExtDirect::Request::JsonRpc',
        data => {
            jsonrpc => '2.0', method => 'Foo.foo_foo', params => ['blerg'], id => 10,
        },
        isa => 'RPC::ExtDirect::Request::JsonRpc',
        result => {
            jsonrpc => '2.0', id => 10, result => "foo! 'blerg'",
        },
    },
    
    {
        name => 'JSON-RPC with named arguments', debug => 1, ran_ok => 1,
        class => 'RPC::ExtDirect::Request::JsonRpc',
        data => {
            jsonrpc => '2.0', method => 'Qux.foo_baz', id => '$@$%@$@#',
            params => {"foo" => "blerg", "bar" => ["throbbe", "zingbong"],
                       "baz" => {"mymse" => "plugh"}},
        },
        isa => 'RPC::ExtDirect::Request::JsonRpc',
        result => {
            jsonrpc => '2.0', id => '$@$%@$@#',
            result => {
                msg => 'foo! bar! baz!',
                foo => 'blerg',
                bar => ['throbbe', 'zingbong'],
                baz => { mymse => 'plugh' },
            },
        },
    },
    
    {
        name => 'JSON-RPC notification', debug => 1, ran_ok => 1,
        class => 'RPC::ExtDirect::Request::JsonRpc',
        isa => 'RPC::ExtDirect::Request::JsonRpc',
        data => {
            jsonrpc => '2.0', method => 'Foo.foo_blessed',
            params => { foo => 'bar' },
        },
        result => undef,
    },
]
