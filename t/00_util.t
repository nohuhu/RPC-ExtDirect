use strict;
use warnings;

use Carp;
use Test::More tests => 36;

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

my $res = eval { $foo->bar() };

is $@,   '',    "Getter didn't die";
is $res, 'baz', "Getter value match";

$res = eval { $foo->bar('qux'); };

is $@,          '',    "Setter didn't die";
is $res,        'qux', "Setter value match";
is $foo->{bar}, 'qux', "Object value match";

$res = $foo->bar();

is $res, 'qux', "Getter after setter value match";

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

# Package flags parsing

package Bar;

use RPC::ExtDirect::Util::Accessor
    qw/ scalar_value empty_scalar
        array_value empty_array
        hash_value empty_hash/;

our $SCALAR_VALUE = 1;
our $EMPTY_SCALAR;

our @ARRAY_VALUE = qw/foo bar/;
our @EMPTY_ARRAY;

our %HASH_VALUE = ( foo => 'bar' );
our %EMPTY_HASH = ();

sub new {
    my $class = shift;

    return bless {@_}, $class;
}

package main;

my $tests = [{
    name   => 'scalar w/ value',
    regex  => qr/^.*?Bar::SCALAR_VALUE.*?scalar_value/ms,
    result => 1,
    flag   => {
        package => 'Bar',
        var     => 'SCALAR_VALUE',
        type    => 'scalar',
        field   => 'scalar_value',
        default => 'foo',
    },
}, {
    name   => 'scalar w/o value',
    regex  => '', # Should be no warning
    result => 'bar',
    flag   => {
        package => 'Bar',
        var     => 'EMPTY_SCALAR',
        type    => 'scalar',
        field   => 'empty_scalar',
        default => 'bar',
    },
}, {
    name   => 'array w/ values',
    regex  => qr/^.*Bar::ARRAY_VALUE.*?array_value/ms,
    result => [qw/ foo bar /],
    flag   => {
        package => 'Bar',
        var     => 'ARRAY_VALUE',
        type    => 'array',
        field   => 'array_value',
        default => [qw/ baz qux /],
    },
}, {
    name   => 'empty array',
    regex  => '',
    result => [qw/ moo fuy /],
    flag   => {
        package => 'Bar',
        var     => 'EMPTY_ARRAY',
        type    => 'array',
        field   => 'empty_array',
        default => [qw/ moo fuy /],
    },
}, {
    name   => 'hash w/ values',
    regex  => qr/^.*Bar::HASH_VALUE.*?hash_value/ms,
    result => { foo => 'bar' },
    flag   => {
        package => 'Bar',
        var     => 'HASH_VALUE',
        type    => 'hash',
        field   => 'hash_value',
        default => { baz => 'qux' },
    },
}, {
    name   => 'empty hash',
    regex  => '',
    result => { mymse => 'fumble' },
    flag   => {
        package => 'Bar',
        var     => 'EMPTY_HASH',
        type    => 'hash',
        field   => 'empty_hash',
        default => { mymse => 'fumble' },
    },
}];

our $warn_msg;

$SIG{__WARN__} = sub { $warn_msg = shift };

for my $test ( @$tests ) {
    my $name   = $test->{name};
    my $regex  = $test->{regex};
    my $result = $test->{result};
    my $flag   = $test->{flag};
    my $type   = $flag->{type};
    my $field  = $flag->{field};
    
    my $obj = new Bar;
    
    $warn_msg = '';

    eval { RPC::ExtDirect::Util::parse_global_flags( [$flag], $obj ) };
    
    is $@, '', "Var $name didn't die";
    
    if ( $regex ) {
        like $warn_msg, $regex, "Var $name warning matches";
    }
    else {
        is $warn_msg, '', "Var $name warning empty";
    }
    
    my $value = $obj->$field();
    
    if ( $type eq 'scalar' ) {
        is ref($value), '', "Var $name type matches";
        is $value, $result, "Var $name value matches";
    }
    else {
        is ref($value), uc $type,  "Var $name type matches";
        is_deeply $value, $result, "Var $name value matches";
    }
};

my $bar = Bar->new( scalar_value => 'fred' );

my $flag = {
    package => 'Bar',
    var     => 'SCALAR_VALUE',
    type    => 'scalar',
    field   => 'scalar_value',
    default => 'foo',
};

RPC::ExtDirect::Util::parse_global_flags( [ $flag ], $bar );

is $bar->scalar_value, 'fred', "Existing object value";

