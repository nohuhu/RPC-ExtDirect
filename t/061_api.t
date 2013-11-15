use strict;
use warnings;

use Test::More tests => 5;

use lib 't/lib';

use RPC::ExtDirect::Config;

# Test modules are so simple they can't be broken
use RPC::ExtDirect::Test::Foo;
use RPC::ExtDirect::Test::Bar;
use RPC::ExtDirect::Test::Qux;

BEGIN { use_ok 'RPC::ExtDirect::API'; }

my $expected = q~
Ext.app.REMOTING_API = {
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
    "type":"remoting",
    "url":"/extdirectrouter"
};
~;

my $api = RPC::ExtDirect->get_api;
$api->config->debug_serialize(1);

my $remoting_api = eval { $api->get_remoting_api() };

# Remove whitespace
s/\s//g for ( $expected, $remoting_api );

is $@,            '',        "remoting_api() 1 eval $@";
is $remoting_api, $expected, "remoting_api() 1 result";

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

$expected = q~
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
~;

$remoting_api = eval {
    RPC::ExtDirect::API->get_remoting_api(config => $config)
};

# Remove whitespace
s/\s//g for ( $expected, $remoting_api );

is $@,            '',        "remoting_api() 2 eval $@";
is $remoting_api, $expected, "remoting_api() 2 result";

