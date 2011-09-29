use strict;
use warnings;
use Carp;

use Test::More tests => 44;

BEGIN { use_ok 'RPC::ExtDirect'; }

use lib 't/lib';

use RPC::ExtDirect::Test::Foo;
use RPC::ExtDirect::Test::Bar;
use RPC::ExtDirect::Test::Qux;
use RPC::ExtDirect::Test::PollProvider;

my %test_for = (
    # foo is plain basic package with ExtDirect methods
    'Foo' => {
        methods => [ sort qw( foo_foo foo_bar foo_baz ) ],
        list    => {
            foo_foo => { package => 'RPC::ExtDirect::Test::Foo',
                         method  => 'foo_foo', param_no => 1,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            foo_bar => { package => 'RPC::ExtDirect::Test::Foo',
                         method  => 'foo_bar', param_no => 2,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            foo_baz => { package => 'RPC::ExtDirect::Test::Foo',
                         method  => 'foo_baz', param_no => 0,
                         formHandler => 0, pollHandler => 0,
                         param_names => [ qw( foo bar baz ) ], },
        },
    },
    # bar package has only its own methods as we don't support inheritance
    'Bar' => {
        methods => [ sort qw( bar_foo bar_bar bar_baz ) ],
        list    => {
            bar_foo => { package => 'RPC::ExtDirect::Test::Bar',
                         method  => 'bar_foo', param_no => 4,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            bar_bar => { package => 'RPC::ExtDirect::Test::Bar',
                         method  => 'bar_bar', param_no => 5,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            bar_baz => { package => 'RPC::ExtDirect::Test::Bar',
                         method  => 'bar_baz', param_no => 0,
                         formHandler => 1, pollHandler => 0,
                         param_names => undef, },
        },
    },
    # Now, qux package redefines all methods so we have 'em here
    'Qux' => {
        methods => [sort qw(foo_foo foo_bar foo_baz bar_foo bar_bar bar_baz)],
        list    => {
            foo_foo => { package => 'RPC::ExtDirect::Test::Qux',
                         method  => 'foo_foo', param_no => 1,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            foo_bar => { package => 'RPC::ExtDirect::Test::Qux',
                         method  => 'foo_bar', param_no => 2,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            foo_baz => { package => 'RPC::ExtDirect::Test::Qux',
                         method  => 'foo_baz', param_no => 0,
                         formHandler => 0, pollHandler => 0,
                         param_names => [ qw( foo bar baz ) ], },
            bar_foo => { package => 'RPC::ExtDirect::Test::Qux',
                         method  => 'bar_foo', param_no => 4,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            bar_bar => { package => 'RPC::ExtDirect::Test::Qux',
                         method  => 'bar_bar', param_no => 5,
                         formHandler => 0, pollHandler => 0,
                         param_names => undef, },
            bar_baz => { package => 'RPC::ExtDirect::Test::Qux',
                         method  => 'bar_baz', param_no => 0,
                         formHandler => 1, pollHandler => 0,
                         param_names => undef, },
        },
    },
    # PollProvider implements Event provider for polling mechanism
    'PollProvider' => {
        methods => [ sort qw( foo ) ],
        list    => {
            foo => { package => 'RPC::ExtDirect::Test::PollProvider',
                     method  => 'foo', param_no => 0,
                     formHandler => 0, pollHandler => 1,
                     param_names => undef, },
        },
    },
);

my @expected_classes = sort qw( Foo Bar Qux PollProvider );

my @full_classes = sort eval { RPC::ExtDirect->get_action_list() };

is        $@, '', "full get_action_list() eval $@";
ok         @full_classes, "full get_action_list() not empty";
is_deeply \@full_classes, \@expected_classes, "full get_action_list() deep";

my @expected_methods = sort qw(
    Qux::bar_bar            Qux::bar_baz        Qux::bar_foo
    Qux::foo_bar            Qux::foo_baz        Qux::foo_foo
    Foo::foo_foo            Foo::foo_bar        Foo::foo_baz
    Bar::bar_foo            Bar::bar_bar        Bar::bar_baz
    PollProvider::foo
);

my @full_methods = sort eval { RPC::ExtDirect->get_method_list() };

is        $@, '',         "full get_method_list() eval $@";
ok         @full_methods, "full get_method_list() not empty";
is_deeply \@full_methods, \@expected_methods, "full get_method_list() deep";

my @expected_poll_handlers = ( [ 'PollProvider', 'foo' ] );

my @full_poll_handlers = eval { RPC::ExtDirect->get_poll_handlers() };

is $@, '',              "full get_poll_handlers() eval $@";
ok @full_poll_handlers, "full get_poll_handlers() not empty";
is_deeply \@full_poll_handlers, \@expected_poll_handlers,
                        "full get_poll_handlers() deep";

# We have RPC::ExtDirect already loaded so let's go
for my $module ( sort keys %test_for ) {
    my $test = $test_for{ $module };

    my @method_list = eval { RPC::ExtDirect->get_method_list($module) };
    is $@, '', "$module get_method_list eval $@";

    my @expected_list = @{ $test->{methods} };

    is_deeply \@method_list, \@expected_list,
                          "$module get_method_list() deeply";

    my %expected_parameter_for = %{ $test->{list  } };

    for my $method_name ( @method_list ) {
        my %parameters = eval {
            RPC::ExtDirect->get_method_parameters($module, $method_name)
        };

        is $@, '', "$module get_method_parameters() list eval $@";

        my $expected_ref = $expected_parameter_for{ $method_name };

        # No way to compare referents (and no sense in that, too);
        delete $parameters{referent};

        is_deeply \%parameters, $expected_ref,
            "$module get_method_parameters() deeply";
    };
};

exit 0;

