package RPC::ExtDirect::Exception;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

### PACKAGE GLOBAL VARIABLE ###
#
# Version of this module.
#

our $VERSION = '1.00';

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of Exception.
#

sub new {
    my ($class, $debug, $message, $where) = @_;

    # Need the object to call private methods
    my $self = bless { debug => $debug }, $class;

    # Store the information internally
    $self->_set_error($message, $where);

    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# A stub for duck typing. Always returns failure.
#

sub run {
    return '';
}

### PUBLIC INSTANCE METHOD ###
#
# Returns exception hashref; named so for duck typing.
#

sub result {
    my ($self) = @_;

    return $self->_get_exception_hashref();
}

### PUBLIC INSTANCE METHODS ###
#
# Read-only getters
#

sub debug   { $_[0]->{debug}   }
sub where   { $_[0]->{where}   }
sub message { $_[0]->{message} }

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Sets internal error condition and message
#

sub _set_error {
    my ($self, $message, $where) = @_;

    # Reconstruct where error happened if not given
    if ( !$where ) {
        my ($package, $sub)
            = (caller 2)[3] =~ / \A (.*) :: (.*?) \z /xms;
        $where = $package . '->' . $sub;
    };

    # Store the information
    $self->{where}   = $where;
    $self->{message} = $message;

    # Ensure fall through for caller methods
    return '';
}

### PRIVATE INSTANCE METHOD ###
#
# Returns exception hashref
#

sub _get_exception_hashref {
    my ($self) = @_;

    # If debug flag is not set, return generic message. This is for
    # compatibility with ExtDirect specification
    my ($where, $message);
    if ( $self->debug ) {
        $where   = $self->where;
        $message = $self->message;
    }
    else {
        $where   = 'ExtDirect';
        $message = 'An error has occured while processing request';
    };

    # Format the hashref
    my $exception_ref = {
        type => 'exception',
        where => $where,
        message => $message,
    };

    return $exception_ref;
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Exception - Provides standard Ext.Direct Exceptions

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
