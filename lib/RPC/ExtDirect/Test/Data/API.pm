package RPC::ExtDirect::Test::Data::API;

# This aref contains definitions/data for API tests
my $tests = [{
    name => 'API 1',
    
    config => {
        api_path => '/api',
        debug => 1,
        no_polling => 1,
        router_path => '/extdirectrouter',
        poll_path => '/events',
    },
    
    input => {
        method => 'GET',
        url => '/api',
        cgi_url => '/api1',
        
        content => undef,
    },
    
    # Expected test output
    output => {
        status => 200,
        content_type => qr|^application/javascript\b|,
        comparator => 'cmp_api',
        content => q~
            Ext.app.REMOTING_API = {
                "actions": {
                "Bar": [
                            { "len":5, "name":"bar_bar" },
                            { "formHandler":true, "len":0, "name":"bar_baz" },
                            { "len":4, "name":"bar_foo" }
                       ],
                "Foo": [
                            { "len":2, "name":"foo_bar" },
                            { "name":"foo_baz", "params":["foo","bar","baz"] },
                            { "len":1, "name":"foo_foo" },
                            { "len":0, "name":"foo_zero" },
                            { "name":"foo_blessed" }
                       ],
                "Qux": [
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
        ~,
    },
}, {
    name => 'API 2',
    
    config => {
        api_path => '/api',
        namespace => 'myApp.ns',
        auto_connect => 1,
        router_path => '/router.cgi',
        debug => 1,
        remoting_var => 'Ext.app.REMOTE_CALL',
        no_polling => 1,
        poll_path => '/events',
    },
    
    input => {
        method => 'GET',
        url => '/api',
        cgi_url => '/api2',
        
        content => undef,
    },
    
    output => {
        status => 200,
        content_type => qr|^application/javascript\b|,
        comparator => 'cmp_api',
        content => q~
            Ext.app.REMOTE_CALL = {
                "actions": {
                "Bar": [
                            { "len":5, "name":"bar_bar" },
                            { "formHandler":true, "len":0, "name":"bar_baz" },
                            { "len":4, "name":"bar_foo" }
                       ],
                "Foo": [
                            { "len":2, "name":"foo_bar" },
                            { "name":"foo_baz", "params":["foo","bar","baz"] },
                            { "len":1, "name":"foo_foo" },
                            { "len":0, "name":"foo_zero" },
                            { "name":"foo_blessed" }
                       ],
                "Qux": [
                            { "len":5, "name":"bar_bar" },
                            { "formHandler":true, "len":0, "name":"bar_baz" },
                            { "len":4, "name":"bar_foo" },
                            { "len":2, "name":"foo_bar" },
                            { "name":"foo_baz", "params":["foo","bar","baz"] },
                            { "len":1, "name":"foo_foo" }
                       ]
                },
                "namespace":"myApp.ns",
                "type":"remoting",
                "url":"/router.cgi"
            };
            Ext.direct.Manager.addProvider(Ext.app.REMOTE_CALL);
        ~,
    },
}, {
    name => 'API 3',
    
    config => {
        remoting_var => 'Ext.app.CALL',
        debug => 1,
        polling_var => 'Ext.app.POLL',
        auto_connect => !1,
        router_path => '/cgi-bin/router.cgi',
        poll_path => '/cgi-bin/events.cgi',
        namespace => 'Namespace',
        api_path => '/api',
        no_polling => !1,
    },
    
    input => {
        method => 'GET',
        url => '/api',
        cgi_url => '/api3',
        
        content => undef,
    },
    
    output => {
        status => 200,
        content_type => qr|^application/javascript\b|,
        comparator => 'cmp_api',
        content => q~
            Ext.app.CALL = {
                "actions": {
                "Bar": [
                            { "len":5, "name":"bar_bar" },
                            { "formHandler":true, "len":0, "name":"bar_baz" },
                            { "len":4, "name":"bar_foo" }
                       ],
                "Foo": [
                            { "len":2, "name":"foo_bar" },
                            { "name":"foo_baz", "params":["foo","bar","baz"] },
                            { "len":1, "name":"foo_foo" },
                            { "len":0, "name":"foo_zero" },
                            { "name":"foo_blessed" }
                       ],
                "Qux": [
                            { "len":5, "name":"bar_bar" },
                            { "formHandler":true, "len":0, "name":"bar_baz" },
                            { "len":4, "name":"bar_foo" },
                            { "len":2, "name":"foo_bar" },
                            { "name":"foo_baz", "params":["foo","bar","baz"] },
                            { "len":1, "name":"foo_foo" }
                       ]
                },
                "namespace":"Namespace",
                "type":"remoting",
                "url":"/cgi-bin/router.cgi"
            };
            Ext.app.POLL = {
                "type":"polling",
                "url":"/cgi-bin/events.cgi"
            };
        ~,
    },
}];

sub get_tests { return $tests };

1;
