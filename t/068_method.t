# Method argument checking preparation

use strict;
use warnings;

use Test::More tests => 59;

use RPC::ExtDirect::Test::Util;
use RPC::ExtDirect::Config;
use RPC::ExtDirect::API;
use RPC::ExtDirect::API::Method;

my $tests = eval do { local $/; <DATA>; } or die "Can't eval DATA: '$@'";

my @run_only = @ARGV;

my $config = RPC::ExtDirect::Config->new();

TEST:
for my $test ( @$tests ) {
    my $name       = $test->{name};
    my $type       = $test->{type};
    my $method_arg = $test->{method};
    my $input      = $test->{input};
    my $out_type   = $test->{out_type};
    my $output     = $test->{output};
    my $exception  = $test->{exception};
    
    next TEST if @run_only && !grep { lc $name eq lc $_ } @run_only;
    
    my $method = RPC::ExtDirect::API::Method->new(
        config => $config,
        %$method_arg,
    );
    
    if ( $type eq 'check' ) {
        my $result = eval { $method->check_method_arguments($input) };
        
        if ( $exception ) {
            like $@, $exception, "$name: check exception";
        }
        else {
            is_deep $result, $output, "$name: check result";
        }
    }
    else {
        my @prep_out = $method->prepare_method_arguments(%$input);
        my $prep_out = $method->prepare_method_arguments(%$input);

        is      ref($prep_out), uc $out_type, "$name: scalar context ref";
        is_deep $prep_out,      $output,      "$name: prepare output";
    }
}

__DATA__

[
    {
        name => 'Ordered passed {}',
        type => 'check',
        method => {
            len => 0,
        },
        input => { foo => 'bar' },
        exception => qr/expects ordered arguments in arrayref/,
    },
    {
        name => 'Ordered zero passed [0]',
        type => 'check',
        method => {
            len => 0,
        },
        input => [],
        output => 1,
    },
    {
        name => 'Ordered zero passed [1]',
        type => 'check',
        method => {
            len => 0,
        },
        input => [42],
        output => 1,
    },
    {
        name => 'Ordered 1 passed [0]',
        type => 'check',
        method => {
            len => 1,
        },
        input => [],
        exception => qr/requires 1 argument\(s\) but only 0 are provided/,
    },
    {
        name => 'Ordered 1 passed [1]',
        type => 'check',
        method => {
            len => 1,
        },
        input => [42],
        output => 1,
    },
    {
        name => 'Ordered 1 passed [2]',
        type => 'check',
        method => {
            len => 1,
        },
        input => [42, 39],
        output => 1,
    },
    {
        name => 'Ordered 3 passed [0]',
        type => 'check',
        method => {
            len => 3,
        },
        input => [],
        exception => qr/requires 3 argument\(s\) but only 0 are provided/,
    },
    {
        name => 'Ordered 3 passed [2]',
        type => 'check',
        method => {
            len => 3,
        },
        input => [111, 222],
        exception => qr/requires 3 argument\(s\) but only 2 are provided/,
    },
    {
        name => 'Ordered 3 passed [3]',
        type => 'check',
        method => {
            len => 3,
        },
        input => [111, 222, 333],
        output => 1,
    },
    {
        name => 'Ordered 3 passed [4]',
        type => 'check',
        method => {
            len => 3,
        },
        input => [111, 222, 333, 444],
        output => 1,
    },
    {
        name => 'Named passed []',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
        },
        input => [],
        exception => qr/expects named arguments in hashref/,
    },
    {
        name => 'Named strict passed empty {}',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
        },
        input => {},
        exception => qr/parameters: 'foo, bar'; these are missing: 'foo, bar'/,
    },
    {
        name => 'Named strict empty params, passed empty {}',
        type => 'check',
        method => {
            params => [],
        },
        input => {},
        output => 1,
    },
    {
        name => 'Named !strict empty params, passed empty {}',
        type => 'check',
        method => {
            params => [],
            strict => !1,
        },
        input => {},
        output => 1,
    },
    {
        name => 'Named strict empty params, passed non-empty {}',
        type => 'check',
        method => {
            params => [],
        },
        input => { foo => 'bar', fred => 'frob', },
        output => 1,
    },
    {
        name => 'Named strict empty params, passed non-empty {}',
        type => 'check',
        method => {
            params => [],
        },
        input => { foo => 'bar', fred => 'frob', },
        output => 1,
    },
    {
        name => 'Named !strict passed empty {}',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
            strict => !1,
        },
        input => {},
        exception => qr/parameters: 'foo, bar'; these are missing: 'foo, bar'/,
    },
    {
        name => 'Named strict not enough arguments',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
        },
        input => { foo => 'bar', },
        exception => qr/parameters: 'foo, bar'; these are missing: 'bar'/,
    },
    {
        name => 'Named !strict not enough arguments',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
            strict => !1,
        },
        input => { foo => 'bar', },
        exception => qr/parameters: 'foo, bar'; these are missing: 'bar'/,
    },
    {
        name => 'Named strict not enough required args',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
        },
        input => { foo => 'bar', baz => 'blerg', fred => 'frob', },
        exception => qr/parameters: 'foo, bar'; these are missing: 'bar'/,
    },
    {
        name => 'Named !strict not enough required args',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
            strict => !1,
        },
        input => { foo => 'bar', baz => 'blerg', fred => 'frob', },
        exception => qr/parameters: 'foo, bar'; these are missing: 'bar'/,
    },
    {
        name => 'Named strict enough args',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
        },
        input => { foo => 'bar', bar => 'baz', },
        output => 1,
    },
    {
        name => 'Named !strict enough args',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
            strict => !1,
        },
        input => { foo => 'bar', bar => 'baz', },
        output => 1,
    },
    {
        name => 'Named strict extra args',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
        },
        input => { foo => 'bar', bar => 'baz', fred => 'frob', },
        output => 1,
    },
    {
        name => 'Named !strict extra args',
        type => 'check',
        method => {
            params => [qw/ foo bar /],
            strict => !1,
        },
        input => { foo => 'bar', bar => 'baz', fred => 'frob', },
        output => 1,
    },
    {
        name => 'formHandler passed []',
        type => 'check',
        method => {
            formHandler => 1,
        },
        input => [],
        exception => qr/expects named arguments in hashref/,
    },
    {
        name => 'formHandler passed {}',
        type => 'check',
        method => {
            formHandler => 1,
        },
        input => {},
        output => 1,
    },
    {
        name => 'pollHandler passed []',
        type => 'check',
        method => {
            pollHandler => 1,
        },
        input => [],
        output => 1,
    },
    {
        name => 'pollHandler passed {}',
        type => 'check',
        method => {
            pollHandler => 1,
        },
        input => {},
        output => 1,
    },
    {
        name => 'Ordered zero no env_arg',
        type => 'prepare',
        method => {
            len => 0,
        },
        input => {
            env => 'env',
            input => [qw/ 1 2 3 /],
        },
        out_type => 'array',
        output => [],
    },
    {
        name => 'Ordered zero env_arg',
        type => 'prepare',
        method => {
            len => 0,
            env_arg => 0,
        },
        input => {
            env => 'env',
            input => [qw/ 1 2 3 /],
        },
        out_type => 'array',
        output => ['env'],
    },
    {
        name => 'Ordered multi 1 no env_arg',
        type => 'prepare',
        method => {
            len => 1,
        },
        input => {
            env => 'env',
            input => [qw/ 1 2 3 /],
        },
        out_type => 'array',
        output => [1],
    },
    {
        name => 'Ordered multi 1 env_arg front',
        type => 'prepare',
        method => {
            len => 1,
            env_arg => 0,
        },
        input => {
            env => 'env',
            input => [qw/ 1 2 3 /],
        },
        out_type => 'array',
        output => ['env', 1],
    },
    {
        name => 'Ordered multi 1 env_arg back',
        type => 'prepare',
        method => {
            len => 1,
            env_arg => 99,
        },
        input => {
            env => 'env',
            input => [qw/ 1 2 3 /],
        },
        out_type => 'array',
        output => [1, 'env'],
    },
    {
        name => 'Ordered multi 2 env_arg middle',
        type => 'prepare',
        method => {
            len => 2,
            env_arg => -1,
        },
        input => {
            env => 'env',
            input => [qw/ 1 2 3 /],
        },
        out_type => 'array',
        output => [1, 'env', 2],
    },
    {
        name => 'Named strict no env',
        type => 'prepare',
        method => {
            params => [qw/ foo bar /],
        },
        input => {
            env => 'env',
            input => { foo => 1, bar => 2, baz => 3 },
        },
        out_type => 'hash',
        output => { foo => 1, bar => 2, },
    },
    {
        name => 'Named lazy no env',
        type => 'prepare',
        method => {
            params => [qw/ foo bar /],
            strict => !1,
        },
        input => {
            env => 'env',
            input => { foo => 1, bar => 2, baz => 3, },
        },
        out_type => 'hash',
        output => { foo => 1, bar => 2, baz => 3, },
    },
    {
        name => 'Named lazy env',
        type => 'prepare',
        method => {
            params => [qw/ foo bar /],
            env_arg => 'env',
            strict => !1,
        },
        input => {
            env => 'env',
            input => { foo => 1, bar => 2, baz => 3, },
        },
        out_type => 'hash',
        output => { foo => 1, bar => 2, baz => 3, env => 'env' },
    },
    {
        name => 'formHandler no uploads no env',
        type => 'prepare',
        method => {
            formHandler => 1,
        },
        input => {
            env => 'env',

            # Test stripping of the standard Ext.Direct fields
            input => {
                action => 'Foo',
                method => 'bar',
                extAction => 'Foo',
                extMethod => 'bar',
                extTID => 1,
                extUpload => 'true',
                _uploads => 'foo',
                foo => 'bar',
            },
        },
        out_type => 'hash',
        output => { foo => 'bar' },
    },
    {
        name => 'formHandler no uploads w/ env',
        type => 'prepare',
        method => {
            formHandler => 1,
            env_arg => '_env',
        },
        input => {
            env => 'env',
            input => { foo => 'bar' },
        },
        out_type => 'hash',
        output => { foo => 'bar', _env => 'env' },
    },
    {
        name => 'formHandler w/def uploads w/ env',
        type => 'prepare',
        method => {
            formHandler => 1,
            env_arg => 'env_',
        },
        input => {
            env => 'env',
            input => { foo => 'bar' },
            upload => [{ baz => 'qux' }],
        },
        out_type => 'hash',
        output => {
            env_ => 'env',
            foo => 'bar',
            file_uploads => [{ baz => 'qux' }],
        },
    },
    {
        name => 'formHandler w/cust uploads w/ env',
        type => 'prepare',
        method => {
            formHandler => 1,
            env_arg => 'env',
            upload_arg => 'files',
        },
        input => {
            env => 'env',
            input => { foo => 'bar', baz => 'bam', },
            upload => [{ baz => 'qux' }],
        },
        out_type => 'hash',
        output => {
            env => 'env',
            foo => 'bar',
            baz => 'bam',
            files => [{ baz => 'qux' }],
        },
    },
    {
        name => 'pollHandler no env',
        type => 'prepare',
        method => {
            pollHandler => 1,
        },
        input => { env => 'env', input => [qw/ foo bar /], },
        out_type => 'array',
        output => [],
    },
    {
        name => 'pollHandler w/ env',
        type => 'prepare',
        method => {
            pollHandler => 1,
            env_arg => 0,
        },
        input => { env => 'env', input => { foo => 'bar' }, },
        out_type => 'array',
        output => ['env'],
    },
];

