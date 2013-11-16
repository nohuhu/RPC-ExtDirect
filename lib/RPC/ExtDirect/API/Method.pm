package RPC::ExtDirect::API::Method;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use RPC::ExtDirect::Config;
use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new Method
#

sub new {
    my ($class, $method) = @_;
    
    $method->{config} ||= RPC::ExtDirect::Config->new();
    
    return bless {
        %$method,
        is_named   => defined $method->{params},
        is_ordered => defined $method->{len},
    }, $class;
}

### PUBLIC INSTANCE METHOD ###
#
# Return a hashref with API definition for this Method
#

sub get_api_definition {
    my ($self) = @_;
    
    # Poll handlers are not declared in the API
    return if $self->pollHandler;
    
    # Form handlers are defined like this
    # (\1 means JSON::true and doesn't force us to `use JSON`)
    return { name => $self->name, len => 0, formHandler => \1 }
        if $self->formHandler;
    
    # Ordinary method with positioned arguments
    return { name => $self->name, len => $self->len + 0 },
        if $self->is_ordered;
    
    # Ordinary method with named arguments
    return { name => $self->name, params => $self->params }
        if $self->params;
    
    # No arguments specified means we're not checking them
    return { name => $self->name };
}

my $accessors = [qw/
    config
    name
    params
    len
    formHandler
    pollHandler
    is_ordered
    is_named
/];

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => $accessors,
);

1;
