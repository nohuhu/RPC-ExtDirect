use strict;
use warnings;

use Test::More tests => 5;

use lib 't/lib';

# Test modules are so simple they can't be broken
use RPC::ExtDirect::Test::Foo;
use RPC::ExtDirect::Test::Bar;
use RPC::ExtDirect::Test::Qux;

BEGIN { use_ok 'RPC::ExtDirect::API'; }

# Set the debug flag
local $RPC::ExtDirect::API::DEBUG = 1;

my $expected = q~
Ext.app.REMOTING_API = {
    "actions":{
        "Bar":[
                { "len":5, "name":"bar_bar" },
                { "formHandler":true, "len":0, "name":"bar_baz" },
                { "len":4, "name":"bar_foo" }
              ],
        "Foo":[
                { "len":2, "name":"foo_bar" },
                { "name":"foo_baz", "params":["foo","bar","baz"] },
                { "len":1, "name":"foo_foo" },
                { "len":0, "name":"foo_zero" }
              ],
        "Qux":[
                { "len":5, "name":"bar_bar" },
                { "formHandler":true, "len":0, "name":"bar_baz" },
                { "len":4, "name":"bar_foo" },
                { "len":2, "name":"foo_bar" },
                { "name":"foo_baz", "params":["foo","bar","baz"] },
                { "len":1, "name":"foo_foo" }
              ]
    },
    "type":"remoting",
    "url":"/extdirectrouter"
};
~;

my $remoting_api = eval { RPC::ExtDirect::API->get_remoting_api() };

# Remove whitespace
s/\s//g for ( $expected, $remoting_api );

is $@,            '',        "remoting_api() 1 eval $@";
is $remoting_api, $expected, "remoting_api() 1 result";

# "Reimport" with parameters

RPC::ExtDirect::API->import(
    namespace    => 'myApp.Server',
    router_path  => '/router.cgi',
    poll_path    => '/poll.cgi',
    remoting_var => 'Ext.app.REMOTE_CALL_API',
    polling_var  => 'Ext.app.REMOTE_EVENT_API',
    auto_connect => 'HELL YEAH!',
);

$expected = q~
Ext.app.REMOTE_CALL_API = {
    "actions":{
        "Bar":[
                { "len":5, "name":"bar_bar" },
                { "formHandler":true, "len":0, "name":"bar_baz" },
                { "len":4, "name":"bar_foo" }
              ],
        "Foo":[
                { "len":2, "name":"foo_bar" },
                { "name":"foo_baz", "params":["foo","bar","baz"] },
                { "len":1, "name":"foo_foo" },
                { "len":0, "name":"foo_zero" }
              ],
        "Qux":[
                { "len":5, "name":"bar_bar" },
                { "formHandler":true, "len":0, "name":"bar_baz" },
                { "len":4, "name":"bar_foo" },
                { "len":2, "name":"foo_bar" },
                { "name":"foo_baz", "params":["foo","bar","baz"] },
                { "len":1, "name":"foo_foo" }
              ]
    },
    "namespace":"myApp.Server",
    "type":"remoting",
    "url":"/router.cgi"
};
Ext.direct.Manager.addProvider(Ext.app.REMOTE_CALL_API);
~;

$remoting_api = eval { RPC::ExtDirect::API->get_remoting_api() };

# Remove whitespace
s/\s//g for ( $expected, $remoting_api );

is $@,            '',        "remoting_api() 2 eval $@";
is $remoting_api, $expected, "remoting_api() 2 result";

exit 0;
