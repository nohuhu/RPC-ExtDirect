package RPC::ExtDirect::Test::Data::Router;

use strict;
use warnings;

# This aref contains definitions/data for Router tests
my $tests = [{
    name => 'Invalid raw POST',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url => '/router1',
    
        content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"something":"invalid":"here"}',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        content => 
            q|{"action":null,"message":"ExtDirect error decoding POST data: |.
            q|            ', or } expected while parsing object/hash,|.
            q|             at character offset 22 (before \":\"here\"}\")'",|.
            q| "method":null, "tid": null, "type":"exception",|.
            q| "where":"RPC::ExtDirect::Serializer->decode_post"}|,
    },
}, {
    name => 'Valid raw POST, single request',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/router1',
    
        content => {
            type => 'raw_post',
            arg  => [
                'http://localhost/router',
                q|{"type":"rpc","tid":1,"action":"Foo",|.
                q| "method":"foo_foo","data":["bar"]}|,
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        content => 
            q|{"action":"Foo","method":"foo_foo",|.
            q|"result":"foo! 'bar'","tid":1,"type":"rpc"}|,
    },
}, {
    name => 'Valid raw POST, multiple requests',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/router1',
    
        content => {
            type => 'raw_post',
            arg  => [
                'http://localhost/router',
                q|[{"tid":1,"action":"Qux","method":"foo_foo",|.
                q|  "data":["foo"],"type":"rpc"},|.
                q| {"tid":2,"action":"Qux","method":"foo_bar",|.
                q|  "data":["bar1","bar2"],"type":"rpc"},|.
                q| {"tid":3,"action":"Qux","method":"foo_baz",|.
                q|  "data":{"foo":"baz1","bar":"baz2",|.
                q|  "baz":"baz3"},"type":"rpc"}]|,
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_str',
        content => 
            q|[{"action":"Qux","method":"foo_foo",|.
            q|"result":"foo! 'foo'","tid":1,"type":"rpc"},|.
            q|{"action":"Qux","method":"foo_bar",|.
            q|"result":["foo! bar!","bar1","bar2"],"tid":2,"type":"rpc"},|.
            q|{"action":"Qux","method":"foo_baz",|.
            q|"result":{"bar":"baz2","baz":"baz3","foo":"baz1",|.
            q|"msg":"foo! bar! baz!"},"tid":3,"type":"rpc"}]|,
    },
}, {
    name => 'Form request, no uploads',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url => '/router1',
    
        content => {
            type => 'form_post',
            arg  => [
                'http://localhost/router',
                action => '/router.cgi',
                method => 'POST',
                extAction => 'Bar',
                extMethod => 'bar_baz',
                extTID => 123,
                field1 => 'foo',
                field2 => 'bar',
                extType => 'rpc',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_str',
        content =>
            q|{"action":"Bar","method":"bar_baz",|.
            q|"result":{"field1":"foo","field2":"bar"},|.
            q|"tid":123,"type":"rpc"}|,
    },
}, {
    name => 'Form request, one upload',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url => '/router2',
    
        content => {
            type => 'form_upload',
            arg  => [
                'http://localhost/router',
                ['qux.txt'],
                action => '/router.cgi',
                method => 'POST',
                extAction => 'JuiceBar',
                extMethod => 'bar_baz',
                extTID => 7,
                extType => 'rpc',
                foo_field => 'foo',
                bar_field => 'bar',
                extUpload => 'true',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^text/html\b|,
        comparator => 'cmp_str',
        content =>
            q|<html><body><textarea>|.
            q|{"action":"JuiceBar","method":"bar_baz",|.
            q|"result":{"bar_field":"bar",|.
            q|"foo_field":"foo",|.
            q|"upload_response":"The following files were |.
            q|processed:\n|.
            q|qux.txt application/octet-stream 31 ok\n"|.
            q|},"tid":7,|.
            q|"type":"rpc"}|.
            q|</textarea></body></html>|,
    },
}, {
    name => 'Form request, multiple uploads',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
    },
    
    input => {
        method => 'POST',
        cgi_url => '/router2',
        url => '/router',
    
        content => {
            type => 'form_upload',
            arg  => [
                'http://localhost/router',
                ['foo.jpg', 'bar.png', 'script.js'],
                action => '/router.cgi',
                method => 'POST',
                extAction => 'JuiceBar',
                extMethod => 'bar_baz',
                extTID => 8,
                field => 'value',
                extUpload => 'true',
                extType => 'rpc',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^text/html\b|,
        comparator => 'cmp_str',
        content =>
            q|<html><body><textarea>|.
            q|{"action":"JuiceBar","method":"bar_baz",|.
            q|"result":{|.
            q|"field":"value",|.
            q|"upload_response":"The following files were |.
            q|processed:\n|.
            q|foo.jpg application/octet-stream 16159 ok\n|.
            q|bar.png application/octet-stream 20693 ok\n|.
            q|script.js application/octet-stream 80 ok\n"|.
            q|},"tid":8,"type":"rpc"}|.
            q|</textarea></body></html>|,
    },
}];

sub get_tests { return $tests };

1;
