# Static (compile time) remoting API generation

use strict;
use warnings;

use Test::More tests => 4;

use RPC::ExtDirect::Test::Util;
use RPC::ExtDirect::Config;

use RPC::ExtDirect::Test::Pkg::Foo;
use RPC::ExtDirect::Test::Pkg::Bar;
use RPC::ExtDirect::Test::Pkg::Qux;
use RPC::ExtDirect::Test::Pkg::Meta;

use RPC::ExtDirect::API;

my $tests = eval do { local $/; <DATA>; } or die "Can't eval DATA: '$@'";

my $want = shift @$tests;

my $api = RPC::ExtDirect->get_api;
$api->config->debug_serialize(1);

my $have = eval { $api->get_remoting_api() };

is      $@,    '',    "remoting_api() 1 eval $@";
cmp_api $have, $want, "remoting_api() 1 result";

# "Reimport" with parameters

my $config = RPC::ExtDirect::Config->new(
    debug_api       => 1,
    debug_serialize => 1,
    namespace       => 'myApp.Server',
    router_path     => '/router.cgi',
    poll_path       => '/poll.cgi',
    remoting_var    => 'Ext.app.REMOTE_CALL_API',
    polling_var     => 'Ext.app.REMOTE_EVENT_API',
    auto_connect    => 'HELL YEAH!',
);

$want = shift @$tests;
$have = eval {
    RPC::ExtDirect::API->get_remoting_api(config => $config)
};

is      $@,    '',    "remoting_api() 2 eval $@";
cmp_api $have, $want, "remoting_api() 2 result";

__DATA__

[
    q~
Ext.app.REMOTING_API = {
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
        "Qux":[
                { "len":1, "name":"foo_foo" },
                { "len":5, "name":"bar_bar" },
                { "len":4, "name":"bar_foo" },
                { "formHandler":true, "len":0, "name":"bar_baz" },
                { "len":2, "name":"foo_bar" },
                { "name":"foo_baz", "params":["foo","bar","baz"] }
        ]
    },
    "type":"remoting",
    "url":"/extdirectrouter"
};
    ~,
    
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
    ~,
]
