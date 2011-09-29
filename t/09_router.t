use strict;
use warnings;

use Test::More tests => 22;

BEGIN { use_ok 'RPC::ExtDirect::Router'; }

# Test modules are simple
use lib 't/lib';
use RPC::ExtDirect::Test::Qux;

my $tests = eval do { local $/; <DATA>; }           ## no critic
    or die "Can't eval DATA: $@";

for my $test ( @$tests ) {
    my $name   = $test->{name};
    my $debug  = $test->{debug};
    my $input  = $test->{input};
    my $expect = $test->{output};

    local $RPC::ExtDirect::Router::DEBUG = $debug;

    my $result = eval { RPC::ExtDirect::Router->route($input) };

    # Remove whitespace
    s/\s//g for ( $expect, $result );

    is        $@,      '',      "$name eval $@";
    is ref    $result, 'ARRAY', "$name result ARRAY";
    is_deeply $result, $expect, "$name result deep";
};

exit 0;

__DATA__
[
    { name   => 'Invalid POST', debug => 1,
      input  => '{"something":"invalid":"here"}',
      output => [ 'application/json',
                  q|{"message":"ExtDirect error decoding POST data: |.
                  q|', or } expected while parsing object/hash, at |.
                  q|character offset 22 (before \":\"here\"}\")'",|.
                  q|"type":"exception",|.
                  q|"where":"RPC::ExtDirect::Deserialize->decode_post"}|
                ],
    },
    { name   => 'Valid POST, single request', debug => 1,
      input  => '{"type":"rpc","tid":1,"action":"Qux","method":"foo_foo",'.
                ' "data":["bar"]}',
      output => [ 'application/json',
                  q|{"action":"Qux","method":"foo_foo",|.
                  q|"result":"foo! 'bar'","tid":1,"type":"rpc"}|
                ],
    },
    { name   => 'Valid POST, multiple requests', debug => 1,
      input  => q|[{"tid":1,"action":"Qux","method":"foo_foo",|.
                q|  "data":["foo"],"type":"rpc"},|.
                q| {"tid":2,"action":"Qux","method":"foo_bar",|.
                q|  "data":["bar1","bar2"],"type":"rpc"},|.
                q| {"tid":3,"action":"Qux","method":"foo_baz",|.
                q|  "data":{"foo":"baz1","bar":"baz2","baz":"baz3"},|.
                q|          "type":"rpc"}]|,
      output => [ 'application/json',
                  q|[{"action":"Qux","method":"foo_foo",|.
                  q|"result":"foo! 'foo'","tid":1,"type":"rpc"},|.
                  q|{"action":"Qux","method":"foo_bar",|.
                  q|"result":["foo! bar!","bar1","bar2"],"tid":2,|.
                  q|"type":"rpc"},|.
                  q|{"action":"Qux","method":"foo_baz",|.
                  q|"result":{"bar":"baz2","baz":"baz3","foo":"baz1",|.
                  q|"msg":"foo! bar! baz!"},"tid":3,"type":"rpc"}]|
                ],
    },
    { name   => 'Invalid form request', debug => 1,
      input  => { extTID => 100, action => 'Bar', method => 'bar_baz',
                  type => 'rpc', data => undef, },
      output => [ 'application/json',
                  q|{"message":"ExtDirect formHandler method |.
                  q|Bar.bar_baz should only be called with form submits",|.
                  q|"type":"exception",|.
                  q|"where":"RPC::ExtDirect::Request->_check_arguments"}|,
                ],
    },
    { name   => 'Form request, no upload', debug => 1,
      input  => { action => '/router_action', method => 'POST',
                  extAction => 'Bar', extMethod => 'bar_baz',
                  extTID => 123, field1 => 'foo', field2 => 'bar', },
      output => [ 'application/json',
                  q|{"action":"Bar","method":"bar_baz",|.
                  q|"result":{"field1":"foo","field2":"bar"},|.
                  q|"tid":123,"type":"rpc"}|,
                ],
    },
    { name   => 'Form request, upload one file', debug => 1,
      input  => { action => '/router.cgi', method => 'POST',
                    extAction => 'Bar', extMethod => 'bar_baz',
                    extTID => 7, foo_field => 'foo', bar_field => 'bar',
                    extUpload => 'true',
                    _uploads => [{ basename => 'foo.txt',
                        type => 'text/plain', handle => {},     # dummy
                        filename => 'C:\Users\nohuhu\foo.txt',
                        path => '/tmp/cgi-upload/foo.txt', size => 123 }],
                },
      output => [ 'text/html',
                  q|<html><body><textarea>|.
                  q|{\"action\":\"Bar\",\"method\":\"bar_baz\",|.
                  q|\"result\":{\"bar_field\":\"bar\",|.
                  q|\"foo_field\":\"foo\",|.
                  q|\"upload_response\":\"The following files were |.
                  q|processed:\n|.
                  q|foo.txt text/plain 123\n\"|.
                  q|},\"tid\":7,|.
                  q|\"type\":\"rpc\"}|.
                  q|</textarea></body></html>|,
                ],
    },
    { name   => 'Form request, multiple uploads', debug => 1,
      input  => { action => '/router_action', method => 'POST',
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
      output => [ 'text/html',
                  q|<html><body><textarea>|.
                  q|{\"action\":\"Bar\",\"method\":\"bar_baz\",|.
                  q|\"result\":{|.
                  q|\"field\":\"value\",|.
                  q|\"upload_response\":\"The following files were |.
                  q|processed:\n|.
                  q|bar.jpg image/jpeg 123123\n|.
                  q|qux.png image/png 54321\n|.
                  q|script.js application/javascript 1000\n\"|.
                  q|},\"tid\":8,\"type\":\"rpc\"}|.
                  q|</textarea></body></html>|,
                ],
    },
]
