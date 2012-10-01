package RPC::ExtDirect::CHECK;

no warnings 'redefine';

use Attribute::Handlers;

sub UNIVERSAL::ExtDirect : ATTR(CODE,CHECK) {
    return RPC::ExtDirect::extdirect(@_);
}

1;

