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

### PACKAGE GLOBAL VARIABLE ###
#
# Turn this on for debugging.
#

our $DEBUG = 0;

### PUBLIC CLASS METHOD ###
#
# Runs all poll handlers in succession, collects the Events returned
# by them and returns serialized representation suitable for passing
# on to client side.
#

sub poll {
    my ($class, $env) = @_;

    # First set the debug flag
    local $RPC::ExtDirect::Serialize::DEBUG = $DEBUG;

    # Compile the list of poll handler
    my @handler_refs = RPC::ExtDirect->get_poll_handlers();

    # Even if we have nothing to poll, we must return a stub Event
    # or client side will throw an unhandled JavaScript exception
    return $class->_no_events unless @handler_refs;

    # Compile the list of poll handler references
    my @poll_handlers;
    for my $handler_ref ( @handler_refs ) {
        my ($action, $method) = @$handler_ref;

        my %params
            = RPC::ExtDirect->get_method_parameters($action, $method);

        push @poll_handlers, \%params;
    };

    # Run all the handlers and collect their outputs
    my @results;

    POLL_HANDLER:
    for my $handler ( @poll_handlers ) {
        next POLL_HANDLER unless defined $handler;

        my (@output, $exception, $method_called);
        my $run_method = 1;

        # Run "before" hook if we got one
        my $before = RPC::ExtDirect::Hook->new('before', $handler);

        if ( $before ) {
            my @hook_output = eval { $before->run($env, [$env]) };

            # If "before" hook died, cancel Method call
            if ( $@ ) {
                $exception  = $@;
                $run_method = '';
            };

            # If "before" hook returns anything but single number 1,
            # or if it dies, we treat this as the result and do not
            # run the poll handler.
            if ( @hook_output != 1 || $hook_output[0] ne '1' ) {
                @output = @hook_output;
                $run_method = '';
            };
        };

        # If "instead" hook is defined, we run it in place of handler
        my $instead = RPC::ExtDirect::Hook->new('instead', $handler);

        my $package  = $handler->{package};
        my $referent = $handler->{referent};

        if ( $run_method ) {
            $method_called = $instead ? $instead->instead
                           :            $referent
                           ;

            @output = $instead ? eval { $instead->run($env, [$env]) }
                    :            eval { $referent->($package, $env) }
                    ;

            $exception = $@;
        };

        # Finally, run the "after" hook if it's defined
        my $after = RPC::ExtDirect::Hook->new('after', $handler);

        if ( $after ) {

            # Return value and exceptions are ignored
            eval {
                $after->run($env, [$env], \@output, $exception, $method_called)
            };
        };

        # Presently there is no way to return an exception to the
        # client side: Ext.Direct PollingProvider code does not have any
        # processing for exceptions and just freaks out upon receiving
        # anything but an event. Passing exceptions disguised as events
        # is kludgy and kinda defeats the whole purpose IMHO.
        # So in fact we just ignore anything exceptional on our side.
        push @results, eval { map { $_->result() } @output }
            unless $@;
    };

    # No events returned by handlers? We still gotta return something.
    return $class->_no_events unless @results;

    # Fortunately, client side does understand more than on event
    # batched as array
    my $final_result = @results > 1 ? [ @results ]
                     :                  $results[0]
                     ;

    # Polling results are always JSON; no content type needed
    my $serialized = eval {
        RPC::ExtDirect::Serialize->serialize( 1, $final_result )
    };

    # And if serialization fails we have to return something positive
    return $@ eq '' && $serialized ? $serialized
           :                         $class->_no_events
           ;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE CLASS METHOD ###
#
# Serializes and returns a NoEvents object.
#

sub _no_events {
    my ($class) = @_;

    my $no_events  = RPC::ExtDirect::NoEvents->new();
    my $result     = $no_events->result();
    my $serialized = RPC::ExtDirect::Serialize->serialize(0, $result);

    return $serialized;
}

### PRIVATE PACKAGE SUBROUTINE ###
#
# Run specified hook
#

sub _run_hook {
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

