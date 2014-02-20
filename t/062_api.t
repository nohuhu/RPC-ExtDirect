use strict;
use warnings;

use Test::More tests => 2;

use RPC::ExtDirect::Test::Util;

use RPC::ExtDirect::Test::Pkg::Foo;
use RPC::ExtDirect::Test::Pkg::Bar;
use RPC::ExtDirect::Test::Pkg::Qux;
use RPC::ExtDirect::Test::Pkg::PollProvider;

use RPC::ExtDirect::API     namespace    => 'myApp.Server',
                            router_path  => '/router.cgi',
                            poll_path    => '/poll.cgi',
                            remoting_var => 'Ext.app.REMOTE_CALL_API',
                            polling_var  => 'Ext.app.REMOTE_EVENT_API',
                            auto_connect => 'HELL YEAH!';

local $RPC::ExtDirect::API::DEBUG = 1;

my $tests = eval do { local $/; <DATA>; }           ## no critic
    or die "Can't eval DATA: '$@'";

# Just silence the warning
$SIG{__WARN__} = sub {};

my $want = deparse_api shift @$tests;
my $have = deparse_api eval { RPC::ExtDirect::API->get_remoting_api() };

is      $@,    '',    "remoting_api() 3 eval $@";
is_deep $have, $want, "remoting_api() 3 result";

__DATA__

[
    q~
        Ext.app.REMOTE_CALL_API = {
            "actions":{
                "Bar":[
                        { "len":5, "name":"bar_bar" },
                        { "len":4, "name":"bar_foo" },
                        { "formHandler":true, "len":0, "name":"bar_baz" }
                      ],
                "Foo":[
                        { "len":1, "name":"foo_foo" },
                        { "len":2, "name":"foo_bar" },
                        { "name":"foo_blessed" },
                        { "name":"foo_baz", "params":["foo","bar","baz"] },
                        { "len":0, "name":"foo_zero" }
                      ],
                "Qux":[
                        { "len":1, "name":"foo_foo" },
                        { "len":5, "name":"bar_bar" },
                        { "len":4, "name":"bar_foo" },
                        { "formHandler":true, "len":0, "name":"bar_baz" },
                        { "len":2, "name":"foo_bar" },
                        { "name":"foo_baz", "params":["foo","bar","baz"] }
                      ]
            },
            "namespace":"myApp.Server",
            "type":"remoting",
            "url":"/router.cgi"
        };
        Ext.direct.Manager.addProvider(Ext.app.REMOTE_CALL_API);
        Ext.app.REMOTE_EVENT_API = {
            "type":"polling",
            "url":"/poll.cgi"
        };
        Ext.direct.Manager.addProvider(Ext.app.REMOTE_EVENT_API);
    ~,
]
