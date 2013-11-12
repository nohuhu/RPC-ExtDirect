package RPC::ExtDirect::API::Action;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Create a new Action instance
#

sub new {
    my ($class, $name, $action) = @_;
    
    # Convert from array of hashrefs to hash of hashrefs
    my %methods = map { $_->{name} => $_ } @$action;

    return bless { name => $name, methods => { %methods } }, $class;
}

### PUBLIC INSTANCE METHOD ###
#
# Returns Client::API::Method object by name
#

sub method {
    my ($self, $method) = @_;

    my $mclass = 'RPC::ExtDirect::Client::API::Method';

    return $mclass->new( {} ) unless $self->{methods}->{$method};
    return $mclass->new( $self->{methods}->{$method} );
}

my $accessors = [qw/ name /];

RPC::ExtDirect::Util::Accessor::create_accessors( simple => $accessors );

1;
