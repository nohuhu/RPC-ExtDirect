#
# WARNING WARNING WARNING
#
# DO NOT CHANGE ANYTHING IN THIS MODULE. OTHERWISE, A LOT OF API 
# AND OTHER TESTS MAY BREAK.
#
# This module is here to test certain behaviors. If you need
# to test something else, add another test module.
# It's that simple.
#

# This does not need to be indexed by PAUSE
package
    RPC::ExtDirect::Test::Pkg::Meta;

use strict;
use warnings;

use RPC::ExtDirect;

sub meta0_default : ExtDirect(0, metadata => { len => 1 }) {
    my ($class, $meta) = @_;

    return { meta => $meta };
}

sub meta0_arg : ExtDirect(0, metadata => { len => 2, arg => 0 }) {
    my ($class, $meta) = @_;

    return { meta => $meta };
}

sub meta1_default : ExtDirect(1, metadata => { len => 1 }) {
    my ($class, $arg1, $meta) = @_;

    return { arg1 => $arg1, meta => $meta };
}

sub meta1_arg : ExtDirect(1, metadata => { len => 2, arg => 0 }) {
    my ($class, $meta, $arg1) = @_;
    
    return { arg1 => $arg1, meta => $meta };
}

sub meta2_default : ExtDirect(2, metadata => { len => 1 }) {
    my ($class, $arg1, $arg2, $meta) = @_;

    return { arg1 => $arg1, arg2 => $arg2, meta => $meta };
}

sub meta2_arg : ExtDirect(2, metadata => { len => 2, arg => 1 }) {
    my ($class, $arg1, $meta, $arg2) = @_;

    return { arg1 => $arg1, arg2 => $arg2, meta => $meta };
}

sub meta_named_default : ExtDirect(params => [], metadata => { len => 1 }) {
    my ($class, %arg) = @_;

    my $meta = delete $arg{metadata};

    return { %arg, meta => $meta };
}

# One line declaration is intentional; Perls below 5.12 have trouble
# parsing attributes spanning multiple lines
sub meta_named_arg : ExtDirect(params => [], metadata => { len => 1, arg => 'foo' }) {
    my ($class, %arg) = @_;

    my $meta = delete $arg{foo};

    return { %arg, meta => $meta };
}

sub meta_named_strict : ExtDirect(params => [], metadata => { params => ['foo'] }) {
    my ($class, %arg) = @_;
    
    my $meta = delete $arg{metadata};

    return { %arg, meta => $meta };
}

sub meta_named_unstrict : ExtDirect(params => [], metadata => { params => [], arg => '_meta' }) {
    my ($class, %arg) = @_;

    my $meta = delete $arg{_meta};

    return { %arg, meta => $meta };
}

1;

