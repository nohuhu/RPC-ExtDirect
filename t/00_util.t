use strict;
use warnings;

use Carp;
use Test::More tests => 7;

BEGIN {
    use_ok 'RPC::ExtDirect::Util';
    use_ok 'RPC::ExtDirect::Util::Accessor';
};

# Accessors

package Foo;

use RPC::ExtDirect::Util::Accessor qw/ bar /;

sub new {
    my ($class, %params) = @_;

    return bless {%params}, $class;
}

sub bleh {
    return RPC::ExtDirect::Util::get_caller_info($_[1]);
}

package main;

my $foo = Foo->new( bar => 'baz' );

my $bar;

eval { $bar = $foo->bar() };

is $@,   '',    "Accessor didn't die";
is $bar, 'baz', "Accessor value match";

# Caller info retrieval

my $info = $foo->bleh(1);

is $info, "Foo->bleh", "caller info";

# die() message cleaning

eval { die "foo bar" };

my $msg = RPC::ExtDirect::Util::clean_error_message($@);

is $msg, "foo bar", "die() message clean";

# croak() message cleaning

eval { croak "moo fred" };

$msg = RPC::ExtDirect::Util::clean_error_message($@);

is $msg, "moo fred", "croak() message clean";

