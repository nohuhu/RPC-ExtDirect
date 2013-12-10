use strict;
use warnings;

use Test::More tests => 4;

use RPC::ExtDirect::Config;
use RPC::ExtDirect::API;

my $api_def = {
    'RPC::ExtDirect::Test::Foo' => {
        methods => {
            foo_foo     => { len => 1 },
            foo_bar     => { len => 2 },
            foo_blessed => { },
            foo_baz     => { params => [qw/ foo bar baz /] },
            foo_zero    => { len => 0 },
        },
    },
    'RPC::ExtDirect::Test::Bar' => {
        methods => {
            bar_bar => { len => 5 },
            bar_foo => { len => 4 },
            bar_baz => { formHandler => 1 },
        },
    },
    'RPC::ExtDirect::Test::Qux' => {
        methods => {
            foo_foo => { len => 1 },
            bar_bar => { len => 5 },
            bar_foo => { len => 4 },
            bar_baz => { formHandler => 1 },
            foo_bar => { len => 2 },
            foo_baz => { params => [qw/ foo bar baz /] },
        },
    },
    'RPC::ExtDirect::Test::PollProvider' => {
        methods => {
            foo => { pollHandler => 1 },
        },
    },
};

my $expected = q~
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

my $config = RPC::ExtDirect::Config->new(
    debug_serialize => 1,
    namespace       => 'myApp.Server',
    router_path     => '/router.cgi',
    poll_path       => '/poll.cgi',
    remoting_var    => 'Ext.app.REMOTE_CALL_API',
    polling_var     => 'Ext.app.REMOTE_EVENT_API',
    auto_connect    => 'HELL YEAH!',
);

my $api = eval {
    RPC::ExtDirect::API->new_from_hashref(
        config   => $config,
        api_href => $api_def,
    )
};

is     $@,   '', "new_from_hashref eval $@";
isa_ok $api, 'RPC::ExtDirect::API';

$api->config->debug_serialize(1);

my $remoting_api = eval { $api->get_remoting_api() };

# Remove whitespace
s/\s//g for ( $expected, $remoting_api );

is $@,            '',        "remoting_api() 4 eval $@";
is $remoting_api, $expected, "remoting_api() 4 result";

