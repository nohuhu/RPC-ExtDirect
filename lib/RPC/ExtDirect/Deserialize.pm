package RPC::ExtDirect::Deserialize;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use JSON;

use RPC::ExtDirect::Request;
use RPC::ExtDirect::Exception;

### PACKAGE GLOBAL VARIABLE ###
#
# Set it to true value to turn on debugging
#

our $DEBUG = 0;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
#

our $EXCEPTION_CLASS = 'RPC::ExtDirect::Exception';

### PACKAGE GLOBAL VARIABLE ###
#
# Set Request class name so it could be configured
#

our $REQUEST_CLASS = 'RPC::ExtDirect::Request';

### PACKAGE GLOBAL VARIABLE ###
#
# JSON decoding options
#

our %JSON_OPTIONS;

### PUBLIC CLASS METHOD ###
#
# Turns JSONified POST request(s) into array of instantiated
# RPC::ExtDirect::Request (Exception) objects. Returns reference
# to array.
#

sub decode_post {
    my ($class, $post_text) = @_;

    # Try to decode data, return Exception upon failure
    my $data = eval { from_json $post_text, \%JSON_OPTIONS };

    # TODO This looks strikingly similar to what Serialize is doing,
    # time for a bit of refactoring?
    if ( $@ ) {
        my $error = $class->_clean_msg($@);

        my $msg = "ExtDirect error decoding POST data: '$error'";
        return [ $class->_exception({ debug => $DEBUG, message => $msg }) ];
    };

    # Normalize data
    $data = [ $data ] unless ref $data eq 'ARRAY';

    # Create array of Requests (or Exceptions)
    my @requests = map { $class->_request($_) } @$data;

    return \@requests;
}

### PUBLIC CLASS METHOD ###
#
# Instantiates Request based on form submitted to ExtDirect handler
# Returns arrayref with single Request.
#

sub decode_form {
    my ($class, $form_hashref) = @_;

    # Create the Request (or Exception)
    my $request = $class->_request($form_hashref);

    return [ $request ];
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Return new Exception object
#

sub _exception {
    my ($self, $params) = @_;
    
    $params->{where} ||= $EXCEPTION_CLASS->get_where(2);
    
    return $EXCEPTION_CLASS->new($params);
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
# Return new Request object
#

sub _request {
    my ($self, $arg) = @_;
    
    return $REQUEST_CLASS->new($arg);
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Deserialize - Handles JSON Ext.Direct requests

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 DEPENDENCIES

RPC::ExtDirect::Deserialize is dependent on the following modules:
L<JSON>

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

