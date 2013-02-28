package RPC::ExtDirect::Serialize;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect::Exception;

use JSON;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn on for debugging
#

our $DEBUG = 0;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
#

our $EXCEPTION_CLASS = 'RPC::ExtDirect::Exception';

### PUBLIC CLASS METHOD ###
#
# Serializes the data passed to it in JSON
#

sub serialize {
    my ($class, $suppress_exceptions, @data) = @_;

    # Try to serialize each response separately;
    # if one fails it's better to return an exception
    # for one response than fail all of them
    my @serialized = map { $class->_encode_response($_, $suppress_exceptions) }
                         @data;

    my $text = @serialized == 1 ? shift @serialized
             :                    '[' . join(',', @serialized) . ']'
             ;

    return $text;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Return new Exception object
#

sub _exception {
    my $self = shift;
    
    return $EXCEPTION_CLASS->new(@_);
}

### PRIVATE INSTANCE METHOD ###
#
# Clean error message
#

sub _clean_msg {
    my ($class, $msg) = @_;
    
    return $EXCEPTION_CLASS->clean_message($msg);
}

### PRIVATE INSTANCE METHOD ###
#
# Try encoding response into JSON
#

sub _encode_response {
    my ($class, $response, $suppress_exceptions) = @_;
    
    my $text = eval { $class->_encode_json($response) };

    if ( $@ and not $suppress_exceptions ) {
        my $msg = $class->_clean_msg($@);

        my $exception = $class->_exception({
            debug   => $DEBUG,
            action  => $response->{action},
            method  => $response->{method},
            tid     => $response->{tid},
            where   => __PACKAGE__,
            message => $msg,
        });
        
        $text = eval { $class->_encode_json( $exception->result() ) };
    };
    
    return $text;
}

### PRIVATE INSTANCE METHOD ###
#
# Actually encode JSON
#

sub _encode_json {
    my ($class, $data) = @_;
    
    return JSON->new->utf8->canonical($DEBUG)->encode($data);
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Serialize - Provides data serialization into JSON

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 DEPENDENCIES

RPC::ExtDirect::Serialize is dependent on the following modules: L<JSON>.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

