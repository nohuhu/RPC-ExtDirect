use strict;
use warnings;
no  warnings 'uninitialized';

use Test::More tests => 17;

use Data::Dumper;
local $Data::Dumper::Indent = 1;

use lib 't/lib';
use RPC::ExtDirect::Test::Hooks;
use RPC::ExtDirect::Test::PollProvider;

use RPC::ExtDirect::Router;
use RPC::ExtDirect::EventProvider;
use RPC::ExtDirect::Event;

use RPC::ExtDirect::API before => \&before_hook, after => \&after_hook;

{
    package RPC::ExtDirect::Event;

    use Data::Dumper;

    use overload '""' => \&stringify,
                 'eq' => \&equals;

    sub stringify {
        my ($self) = @_;

        local $Data::Dumper::Indent = 0;
        local $Data::Dumper::Terse  = 1;

        return $self->name . ':' . Dumper( $self->data );
    }

    sub equals {
        my ($self, $comparison) = @_;

        return $self->stringify eq "$comparison";
    }

    # This cheating is to avoid rewriting test modules

    package RPC::ExtDirect::Test::Hooks;

    RPC::ExtDirect->import( Action => 'Hooks',
                            before => \&main::before_hook,
                            after  => \&main::after_hook );
}

BEGIN { use_ok 'RPC::ExtDirect::Hook' };

# These variables get set when hooks are called
my ($before, $after, $modify, $throw_up, $cancel);

sub before_hook {
    my ($class, %params) = @_;

    $before = [ $class, { %params } ];

    $params{arg}->[0] = 'bar' if $modify;

    die "Exception\n" if $throw_up;

    return "Method canceled" if $cancel;

    return 1;
}

sub after_hook {
    $after = [ shift @_, { @_ } ];
}

my $tests = eval do { local $/; <DATA> };
die "Can't read DATA: $@\n" if $@;

for my $test ( @$tests ) {
    my $name       = $test->{name};
    my $input      = $test->{input};
    my $type       = $test->{type};
    my $env        = $test->{env};
    my $exp_before = $test->{expected_before};
    my $exp_after  = $test->{expected_after};
    
    $before = $after = $modify = $throw_up = $cancel = undef;
    
    $modify   = $test->{modify};
    $throw_up = $test->{throw_up};
    $cancel   = $test->{cancel};
    
    if ( $type eq 'router' ) {
        RPC::ExtDirect::Router->route($input, $env);
    }
    else {
        RPC::ExtDirect::EventProvider->poll($env);
    };

    # Orig is a closure in RPC::ExtDirect::Hook, impossible to take ref of
    eval { delete $before->[1]->{orig}; delete $after->[1]->{orig}; };
    $@ = undef;

    is_deeply $before, $exp_before, "$name: before data"
        or diag( Data::Dumper->Dump( [$before], ['before'] ) );
    
    is_deeply $after,  $exp_after,  "$name: after data"
        or diag( Data::Dumper->Dump( [$after], ['after'] ) );

};

__DATA__
[
    # Cancel Method call by throwing error
    {
        name => 'Router throw error',
        input => q|{"type":"rpc","tid":1,"action":"Hooks",|.
                 q|"method":"foo_hook","data":["foo"]}|,
        env => 'env',
        throw_up => 1,
        type => 'router',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::Hooks',
                method      => 'foo_hook',
                code        => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg         => [ 'foo', 'env' ],
                env         => 'env',
                param_names => undef,
                param_no    => 1,
                pollHandler => 0,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::Hooks',
                method        => 'foo_hook',
                code          => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg           => [ 'foo', 'env' ],
                env           => 'env',
                result        => undef,
                exception     => "Exception\n",
                param_names   => undef,
                param_no      => 1,
                pollHandler   => 0,
                formHandler   => 0,
                method_called => undef,
            },
        ],
    },

    # Cancel Method call by returning non-1 from before hook
    {
        name => 'Router cancel Method',
        input => q|{"type":"rpc","tid":1,"action":"Hooks",|.
                 q|"method":"foo_hook","data":["foo"]}|,
        env => 'env',
        cancel => 1,
        type => 'router',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::Hooks',
                method      => 'foo_hook',
                code        => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg         => [ 'foo', 'env' ],
                env         => 'env',
                param_names => undef,
                param_no    => 1,
                pollHandler => 0,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::Hooks',
                method        => 'foo_hook',
                code          => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg           => [ 'foo', 'env' ],
                env           => 'env',
                result        => 'Method canceled',
                exception     => undef,
                param_names   => undef,
                param_no      => 1,
                pollHandler   => 0,
                formHandler   => 0,
                method_called => undef,
            },
        ],
    },

    # Simple Router request
    {
        name => 'Router method call',
        input => q|{"type":"rpc","tid":1,"action":"Hooks",|.
                 q|"method":"foo_hook","data":["foo"]}|,
        env => 'env',
        type => 'router',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::Hooks',
                method      => 'foo_hook',
                code        => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg         => [ 'foo', 'env' ],
                env         => 'env',
                param_names => undef,
                param_no    => 1,
                pollHandler => 0,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::Hooks',
                method        => 'foo_hook',
                code          => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg           => [ 'foo', 'env' ],
                env           => 'env',
                result        => [ 'RPC::ExtDirect::Test::Hooks', 'foo', 'env' ],
                exception     => '',
                param_names   => undef,
                param_no      => 1,
                pollHandler   => 0,
                formHandler   => 0,
                method_called => \&RPC::ExtDirect::Test::Hooks::foo_hook,
            },
        ],
    },

    # Argument modification in "before" hook
    {
        name => 'Router arg modification',
        input => q|{"type":"rpc","tid":1,"action":"Hooks",|.
                 q|"method":"foo_hook","data":["foo"]}|,
        env => 'env',
        modify => 1,
        type => 'router',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::Hooks',
                method      => 'foo_hook',
                code        => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg         => [ 'bar', 'env' ],
                env         => 'env',
                param_names => undef,
                param_no    => 1,
                pollHandler => 0,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::Hooks',
                method        => 'foo_hook',
                code          => \&RPC::ExtDirect::Test::Hooks::foo_hook,
                arg           => [ 'bar', 'env' ],
                env           => 'env',
                result        => [ 'RPC::ExtDirect::Test::Hooks', 'bar', 'env' ],
                exception     => '',
                param_names   => undef,
                param_no      => 1,
                pollHandler   => 0,
                formHandler   => 0,
                method_called => \&RPC::ExtDirect::Test::Hooks::foo_hook,
            },
        ],
    },

    # Cancel EventProvider call by throwing error
    {
        name => 'Poll throw error',
        env => 'env',
        throw_up => 1,
        type => 'poll',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::PollProvider',
                method      => 'foo',
                code        => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg         => [ 'env' ],
                env         => 'env',
                param_names => undef,
                param_no    => 0,
                pollHandler => 1,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::PollProvider',
                method        => 'foo',
                code          => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg           => [ 'env' ],
                env           => 'env',
                result        => [],
                exception     => "Exception\n",
                param_names   => undef,
                param_no      => 0,
                pollHandler   => 1,
                formHandler   => 0,
                method_called => undef,
            },
        ],
    },

    # Cancel Method call by returning non-1 from before hook
    {
        name => 'Poll cancel Method',
        env => 'env',
        cancel => 1,
        type => 'poll',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::PollProvider',
                method      => 'foo',
                code        => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg         => [ 'env' ],
                env         => 'env',
                param_names => undef,
                param_no    => 0,
                pollHandler => 1,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::PollProvider',
                method        => 'foo',
                code          => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg           => [ 'env' ],
                env           => 'env',
                result        => [ 'Method canceled' ],
                exception     => undef,
                param_names   => undef,
                param_no      => 0,
                pollHandler   => 1,
                formHandler   => 0,
                method_called => undef,
            },
        ],
    },

    # Argument modification in "before" hook
    {
        name => 'Poll arg modification',
        env => 'env',
        modify => 1,
        type => 'poll',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::PollProvider',
                method      => 'foo',
                code        => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg         => [ 'bar' ],
                env         => 'env',
                param_names => undef,
                param_no    => 0,
                pollHandler => 1,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::PollProvider',
                method        => 'foo',
                code          => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg           => [ 'env' ],
                env           => 'env',
                result        => [q|foo_event:['foo']|, q|bar_event:{'foo' => 'bar'}|],
                exception     => '',
                param_names   => undef,
                param_no      => 0,
                pollHandler   => 1,
                formHandler   => 0,
                method_called => \&RPC::ExtDirect::Test::PollProvider::foo,
            },
        ],
    },

    # Event polling
    {
        name => 'Poll method call',
        env => 'env',
        type => 'poll',
        expected_before => [
            'main',
            {
                before      => \&before_hook,
                instead     => undef,
                after       => \&after_hook,
                package     => 'RPC::ExtDirect::Test::PollProvider',
                method      => 'foo',
                code        => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg         => [ 'env' ],
                env         => 'env',
                param_names => undef,
                param_no    => 0,
                pollHandler => 1,
                formHandler => 0,
            },
        ],
        expected_after => [
            'main',
            {
                before        => \&before_hook,
                instead       => undef,
                after         => \&after_hook,
                package       => 'RPC::ExtDirect::Test::PollProvider',
                method        => 'foo',
                code          => \&RPC::ExtDirect::Test::PollProvider::foo,
                arg           => [ 'env' ],
                env           => 'env',
                result        => [q|foo_event:['foo']|, q|bar_event:{'foo' => 'bar'}|],
                exception     => '',
                param_names   => undef,
                param_no      => 0,
                pollHandler   => 1,
                formHandler   => 0,
                method_called => \&RPC::ExtDirect::Test::PollProvider::foo,
            },
        ],
    },
]
