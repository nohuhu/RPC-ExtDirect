package RPC::ExtDirect::API::Method;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new Client::API::Method
#

sub new {
    my ($class, $method) = @_;

    return bless $method, $class;
}

### PUBLIC INSTANCE METHOD ###
#
# Check if this Method accepts named parameters
#

sub is_named { !!$_[0]->{params} }

### PUBLIC INSTANCE METHOD ###
#
# Check if this Method accepts ordered parameters
#

sub is_ordered { $_[0]->{len} > 0 }

### PUBLIC INSTANCE METHOD ###
#
# Check if this Method is a form handler
#

sub is_formhandler { !!$_[0]->{formHandler} }

### PUBLIC INSTANCE METHOD ###
#
# Return the length of the parameter list, defaults to 0
#

sub len { $_[0]->{len} || 0 }

my $accessors = [qw/ name params formHandler /];

RPC::ExtDirect::Util::Accessor::create_accessors( simple => $accessors );

1;
