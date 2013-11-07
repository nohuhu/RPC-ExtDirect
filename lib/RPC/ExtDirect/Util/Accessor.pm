package RPC::ExtDirect::Util::Accessor;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

### PUBLIC PACKAGE SUBROUTINE ###
#
# Generate accessors for the list of properties passed in.
#

sub import {
    my ($class, @properties) = @_;
    
    return unless @properties;
    
    my $caller_class = caller();
    
    for my $prop ( @properties ) {
        no strict 'refs';
    
        *{ $caller_class . '::' . $prop } = sub {
            @_ == 1 ? $_[0]->{$prop} : ($_[0]->{$prop} = $_[1])
        };
    }
}

1;
