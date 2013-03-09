package RPC::ExtDirect::EventProvider;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect ();       # No imports needed here
use RPC::ExtDirect::Serialize;
use RPC::ExtDirect::Event;
use RPC::ExtDirect::NoEvents;
use RPC::ExtDirect::Hook;
use RPC::ExtDirect::Request::PollHandler;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn this on for debugging.
#

our $DEBUG = 0;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Serializer class name so it could be configured
#
# TODO This is hacky hack, find another way to inject
# new functionality (all class names)
#

our $SERIALIZER_CLASS = 'RPC::ExtDirect::Serialize';

### PACKAGE GLOBAL VARIABLE ###
#
# Set Event class name so it could be configured
#

our $EVENT_CLASS = 'RPC::ExtDirect::Event';

### PACKAGE GLOBAL VARIABLE ###
#
# Set Request class name so it could be configured
#

our $REQUEST_CLASS = 'RPC::ExtDirect::Request::PollHandler';

### PUBLIC CLASS METHOD ###
#
# Runs all poll handlers in succession, collects the Events returned
# by them and returns serialized representation suitable for passing
# on to client side.
#

sub poll {
    my ($class, $env) = @_;
    
    no strict 'refs';

    # First set the debug flag
    local ${$SERIALIZER_CLASS.'::DEBUG'} = $DEBUG;

    my @poll_handlers = $class->_get_poll_handlers();

    # Even if we have nothing to poll, we must return a stub Event
    # or client side will throw an unhandled JavaScript exception
    return $class->_no_events unless @poll_handlers;

    # Run all the handlers and collect their outputs
    my @results = $class->_run_handlers($env, \@poll_handlers);

    # No events returned by handlers? We still gotta return something.
    return $class->_no_events unless @results;

    # Polling results are always JSON; no content type needed
    my $serialized = $class->_serialize_results(@results);

    # And if serialization fails we have to return something positive
    return $serialized || $class->_no_events;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE CLASS METHOD ###
#
# Return the list of poll handlers
#

sub _get_poll_handlers {
    my ($class) = @_;

    # Compile the list of poll handler
    my @handler_refs = RPC::ExtDirect->get_poll_handlers();

    # Compile the list of poll handler references
    my @poll_handlers;
    for my $handler_ref ( @handler_refs ) {
        my $req = $class->_create_request($handler_ref);

        push @poll_handlers, $req if $req;
    };
    
    return @poll_handlers;
}

### PRIVATE CLASS METHOD ###
#
# Create Request off poll handler
#

sub _create_request {
    my ($class, $handler) = @_;
    
    my ($action, $method) = @$handler;
    
    my $req = $REQUEST_CLASS->new({
        action  => $action,
        method  => $method,
    });
    
    return $req;
}

### PRIVATE CLASS METHOD ###
#
# Run poll handlers and collect results
#

sub _run_handlers {
    my ($class, $env, $requests) = @_;
    
    # Run the requests
    $_->run($env) for @$requests;

    # Collect responses
    my @results = map { $_->result } @$requests;
    
    return @results;
}

### PRIVATE CLASS METHOD ###
#
# Serialize result
#

sub _serialize_results {
    my ($class, @results) = @_;

    # Fortunately, client side does understand more than on event
    # batched as array
    my $final_result = @results > 1 ? [ @results ]
                     :                  $results[0]
                     ;

    my $json = eval {
        $SERIALIZER_CLASS->serialize( 1, $final_result )
    };

    return $json;
}

### PRIVATE CLASS METHOD ###
#
# Serializes and returns a NoEvents object.
#

sub _no_events {
    my ($class) = @_;

    my $no_events  = RPC::ExtDirect::NoEvents->new();
    my $result     = $no_events->result();
    my $serialized = $SERIALIZER_CLASS->serialize(0, $result);

    return $serialized;
}

### PRIVATE PACKAGE SUBROUTINE ###
#
# Run specified hook
#

sub __run_hook {
    my ($hook, $handler, $env, $output, $exception) = @_;

    my %params = %$handler;

    # Poll handlers are only passed env object as parameter
    $params{arg} = [ $env ];

    $params{code} = delete $params{referent};
    $params{orig} = sub {
        my ($code, $package, $arg) = @params{ qw/code package arg/ };

        return $code->($package, $arg);
    };
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::EventProvider - Collects Events and returns serialized stream

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

