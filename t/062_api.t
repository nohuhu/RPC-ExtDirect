# Static (compile time) remoting/polling API configuration via import

use strict;
use warnings;

use Test::More tests => 2;

use RPC::ExtDirect::Test::Util;

use RPC::ExtDirect::Test::Pkg::Foo;
use RPC::ExtDirect::Test::Pkg::Bar;
use RPC::ExtDirect::Test::Pkg::Qux;
use RPC::ExtDirect::Test::Pkg::Meta;
use RPC::ExtDirect::Test::Pkg::PollProvider;

use RPC::ExtDirect::API     namespace    => 'myApp.Server',
                            router_path  => '/router.cgi',
                            poll_path    => '/poll.cgi',
                            remoting_var => 'Ext.app.REMOTE_CALL_API',
                            polling_var  => 'Ext.app.REMOTE_EVENT_API',
                            auto_connect => 'HELL YEAH!';

local $RPC::ExtDirect::API::DEBUG = 1;

my $tests = eval do { local $/; <DATA>; } or die "Can't eval DATA: '$@'";

# Silence the package globals warning
$SIG{__WARN__} = sub {};

my $want = shift @$tests;
my $have = eval { RPC::ExtDirect::API->get_remoting_api() };

is      $@,    '',    "remoting_api() eval $@";
cmp_api $have, $want, "remoting_api() result";

__DATA__

[
    q~
Ext.app.REMOTE_CALL_API = {
    "actions":{
        "Bar": [
                { "len":5, "name":"bar_bar" },
                { "len":4, "name":"bar_foo" },
                { "formHandler":true, "len":0, "name":"bar_baz" }
        ],
        "Foo": [
                { "len":1, "name":"foo_foo" },
                { "len":2, "name":"foo_bar" },
                { "name":"foo_blessed", "params":[], "strict":false },
                { "name":"foo_baz", "params":["foo","bar","baz"] },
                { "len":0, "name":"foo_zero" }
        ],
        "Meta": [
                { "name":"meta0_default", "len":0, "metadata":{ "len":1 } },
                { "name":"meta0_arg", "len":0, "metadata":{ "len":2 } },
                { "name":"meta1_default", "len":1, "metadata":{ "len":1 } },
                { "name":"meta1_arg", "len":1, "metadata":{ "len":2 } },
                { "name":"meta2_default", "len":2, "metadata":{ "len":1 } },
                { "name":"meta2_arg", "len":2, "metadata":{ "len":2 } },
                { "name":"meta_named_default", "params": [], "strict":false,
                  "metadata": { "len": 1 } },
                { "name":"meta_named_arg", "params": [], "strict":false,
                  "metadata": { "len": 1 } },
                { "name":"meta_named_strict", "params": [], "strict":false,
                  "metadata": { "params": ["foo"] } },
                { "name":"meta_named_unstrict", "params": [], "strict":false,
                  "metadata": { "params": [], "strict": false } }
        ],
        "Qux": [
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
