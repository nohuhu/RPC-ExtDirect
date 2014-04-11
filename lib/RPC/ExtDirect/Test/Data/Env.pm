package RPC::ExtDirect::Test::Data::Env;

# This aref contains definitions/data for Env tests
my $tests = [{
    name => 'http list',
        
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
        
        -cgi_env => {
            HTTP_COOKIE => 'foo=bar',
        },
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/env',
        
        content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"type":"rpc","tid":1,"action":"Env",'.
                ' "method":"http_list","data":[]}',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        cgi_content =>
            q|{"action":"Env","method":"http_list","result":|.
            q|["HTTP_ACCEPT","HTTP_ACCEPT_CHARSET","HTTP_CONNECTION",|.
            q|"HTTP_COOKIE","HTTP_HOST","HTTP_USER_AGENT"],|.
            q|"tid":1,"type":"rpc"}|,
        plack_content =>
            q|{"action":"Env","method":"http_list","result":|.
            q|["COOKIE","Content-Length","Content-Type","Host"],|.
            q|"tid":1,"type":"rpc"}|,
        anyevent_content =>
            q|{"action":"Env","method":"http_list","result":|.
            q|["content-length","content-type","cookie"],|.
            q|"tid":1,"type":"rpc"}|,
    },
}, {
    name => 'http header',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
        
        -cgi_env => {
            HTTP_COOKIE => 'foo=bar',
        },
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/env',
        
        cgi_content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"type":"rpc","tid":1,"action":"Env",'.
                ' "method":"http_header","data":["HTTP_USER_AGENT"]}',
            ],
        },
        
        content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"type":"rpc","tid":1,"action":"Env",'.
                ' "method":"http_header","data":["Content-Type"]}',
            ],
        }
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        cgi_content => 
            q|{"action":"Env","method":"http_header","result":|.
            q|"CGI::Test",|.
            q|"tid":1,"type":"rpc"}|,
        content =>
            q|{"action":"Env","method":"http_header","result":|.
            q|"application/json",|.
            q|"tid":1,"type":"rpc"}|,
    },
}, {
    name => 'param list',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
        
        -cgi_env => {
            HTTP_COOKIE => 'foo=bar',
        },
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/env',
        
        content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"type":"rpc","tid":1,"action":"Env",'.
                ' "method":"param_list","data":[]}',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        anyevent_content =>
            q|{"action":"Env","method":"param_list","result":|.
            q|[],|.
            q|"tid":1,"type":"rpc"}|,
        content =>
            q|{"action":"Env","method":"param_list","result":|.
            q|["POSTDATA"],|.
            q|"tid":1,"type":"rpc"}|,
    },
}, {
    name => 'param get',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
        
        -cgi_env => {
            HTTP_COOKIE => 'foo=bar',
        },
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/env',
        
        content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"type":"rpc","tid":1,"action":"Env",'.
                ' "method":"param_get","data":["POSTDATA"]}',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        anyevent_content =>
            q|{"action":"Env","method":"param_get","result":|.
            q|null,|.
            q|"tid":1,"type":"rpc"}|,
        content =>
            q|{"action":"Env","method":"param_get","result":|.
            q|"{\"type\":\"rpc\",\"tid\":1,\"action\":\"Env\",\"method\":\"param_get\",\"data\":[\"POSTDATA\"]}",|.
            q|"tid":1,"type":"rpc"}|,
    },
}, {
    name => 'cookie list',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
        
        -cgi_env => {
            HTTP_COOKIE => 'foo=bar',
        },
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/env',
        
        content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"type":"rpc","tid":1,"action":"Env",'.
                ' "method":"cookie_list","data":[]}',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        content =>
            q|{"action":"Env","method":"cookie_list","result":|.
            q|["foo"],|.
            q|"tid":1,"type":"rpc"}|,
    },
}, {
    name => 'cookie get',
    
    config => {
        api_path => '/api',
        router_path => '/router',
        poll_path => '/events',
        debug => 1,
        
        -cgi_env => {
            HTTP_COOKIE => 'foo=bar',
        },
    },
    
    input => {
        method => 'POST',
        url => '/router',
        cgi_url  => '/env',
        
        content => {
            type => 'raw_post',
            arg => [
                'http://localhost/router',
                '{"type":"rpc","tid":1,"action":"Env",'.
                ' "method":"cookie_get","data":["foo"]}',
            ],
        },
    },
    
    output => {
        status => 200,
        content_type => qr|^application/json\b|,
        comparator => 'cmp_json',
        content =>
            q|{"action":"Env","method":"cookie_get","result":|.
            q|"bar",|.
            q|"tid":1,"type":"rpc"}|,
    },
}];

sub get_tests { return $tests };

1;