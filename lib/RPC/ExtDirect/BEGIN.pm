package RPC::ExtDirect::BEGIN;

no warnings 'redefine';

use Attribute::Handlers;

sub UNIVERSAL::ExtDirect : ATTR(CODE,BEGIN) {
    return RPC::ExtDirect::extdirect(@_);
}

1;

