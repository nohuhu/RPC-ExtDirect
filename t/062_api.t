use strict;
use warnings;

use Test::More tests => 2;

use RPC::ExtDirect::Test::Util;

# Test modules are so simple they can't be broken
use RPC::ExtDirect::Test::Foo;
use RPC::ExtDirect::Test::Bar;
use RPC::ExtDirect::Test::Qux;
use RPC::ExtDirect::Test::PollProvider;

use RPC::ExtDirect::API     namespace    => 'myApp.Server',
                            router_path  => '/router.cgi',
                            poll_path    => '/poll.cgi',
                            remoting_var => 'Ext.app.REMOTE_CALL_API',
                            polling_var  => 'Ext.app.REMOTE_EVENT_API',
                            auto_connect => 'HELL YEAH!';

local $RPC::ExtDirect::API::DEBUG = 1;

my $expected = deparse_api q~
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
~;

# Just silence the warning
$SIG{__WARN__} = sub {};

my $remoting_api = deparse_api eval { RPC::ExtDirect::API->get_remoting_api() };

is      $@,            '',        "remoting_api() 3 eval $@";
is_deep $remoting_api, $expected, "remoting_api() 3 result";

