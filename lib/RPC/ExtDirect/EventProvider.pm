package RPC::ExtDirect::EventProvider;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect ();       # No imports needed here
use RPC::ExtDirect::Serialize;
use RPC::ExtDirect::Event;
use RPC::ExtDirect::NoEvents;

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
    my ($class) = @_;

    # First set the debug flag
    local $RPC::ExtDirect::Serialize::DEBUG = $DEBUG;

    # Compile the list of poll handler
    my @handler_refs = RPC::ExtDirect->get_poll_handlers();

    # Even if we have nothing to poll, we must return a stub Event
    return $class->_no_events unless @handler_refs;

    # Compile the list of poll handler references
    my @code_refs;
    for my $handler_ref ( @handler_refs ) {
        my $action = $handler_ref->[0];
        my $method = $handler_ref->[1];

        my %params
            = RPC::ExtDirect->get_method_parameters($action, $method);

        push @code_refs, $params{referent};
    };

    # Run all the handlers and collect their outputs
    my @results;
    CODE_REF:
    for my $code_ref ( @code_refs ) {
        next CODE_REF unless defined $code_ref;

        my @output = eval { $code_ref->() };

        # XXX Presently there is no way to return an exception to the
        # client side: Ext.Direct PollingProvider code does not have any
        # processing for exceptions and just freaks out upon receiving
        # anything but an event. Passing exceptions disguised as events
        # is kludgy and kinda defeats the whole purpose IMHO.
        # So in fact we just ignore anything exceptional on our side.
        # *SIGH*
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

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
