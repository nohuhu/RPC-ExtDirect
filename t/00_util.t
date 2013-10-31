use strict;
use warnings;

use Test::More tests => 3;

BEGIN { use_ok 'RPC::ExtDirect::Util::Accessor' };

package Foo;

use RPC::ExtDirect::Util::Accessor qw/ bar /;

sub new {
    my ($class, %params) = @_;

    return bless {%params}, $class;
}

package main;

my $foo = Foo->new( bar => 'baz' );

my $bar;

eval { $bar = $foo->bar() };

is $@,   '',    "Accessor didn't die";
is $bar, 'baz', "Accessor value match";

