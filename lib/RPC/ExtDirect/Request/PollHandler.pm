package RPC::ExtDirect::Request::PollHandler;

# This private class implements overrides for Request
# to be used with EventProvider

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use base 'RPC::ExtDirect::Request';

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of RPC::ExtDirect::Request
#

sub new {
    my ($class, $arguments) = @_;
    
    my $self = $class->SUPER::new($arguments);
    
    # We can't return exceptions from poll handler anyway
    return $self->{message} ? undef : $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Return Events data extracted
#

sub result {
    my ($self) = @_;

    my $events = $self->{result};
    
    # A hook can return something that is not event list
    $events = [] unless 'ARRAY' eq ref $events;
    
    return @$events ? map { $_->result } @$events : ();
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Checks if method arguments are in order
#

sub _check_arguments {
    my ($self, %params) = @_;
    
    # There are no parameters to poll handlers
    # so we return undef which means no error
    return undef;       ## no critic
}

### PRIVATE INSTANCE METHOD ###
#
# Prepares method arguments to be passed along to the method
#

sub _prepare_method_arguments {
    my ($self, $env) = @_;
    
    return ($env);
}
   
### PRIVATE INSTANCE METHOD ###
#
# Actually run the method or hook and return result
#

sub _do_run_method {
    my ($self, $env, $arg) = @_;
    
    my $package  = $self->package;
    my $referent = $self->referent;
    
    my @events = $referent->($package, @$arg);
    
    return [@events];
}

### PRIVATE INSTANCE METHOD ###
#
# Handles errors
#

sub _set_error {
    my ($self) = @_;
    
    $self->{result} = [];
}

1;
