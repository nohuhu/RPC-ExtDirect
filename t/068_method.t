# Method argument preparation

use strict;
use warnings;

use Test::More tests => 15;

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
    my $method_arg = $test->{method};
    my $input      = $test->{input};
    my $out_type   = $test->{out_type};
    my $output     = $test->{output};

    next TEST if @run_only && !grep { lc $name eq lc $_ } @run_only;

    my $method = RPC::ExtDirect::API::Method->new(
        config => $config,
        %$method_arg,
    );

    my @prep_arg = $method->prepare_method_arguments(%$input);

    my $arg = $out_type eq 'array' ? [ @prep_arg ] : { @prep_arg };

    is_deep $arg, $output, "$name: output";
}

__DATA__

[
    {
        name => 'Ordered zero no env_arg',
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
        method => {
            pollHandler => 1,
        },
        input => { env => 'env', input => [qw/ foo bar /], },
        out_type => 'array',
        output => [],
    },
    {
        name => 'pollHandler w/ env',
        method => {
            pollHandler => 1,
            env_arg => 0,
        },
        input => { env => 'env', input => { foo => 'bar' }, },
        out_type => 'array',
        output => ['env'],
    },
];

