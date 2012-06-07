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

### PUBLIC CLASS METHOD ###
#
# Turns JSONified POST request(s) into array of instantiated
# RPC::ExtDirect::Request (Exception) objects. Returns reference
# to array.
#

sub decode_post {
    my ($class, $post_text) = @_;

    # Shortcuts
    my $rqst = 'RPC::ExtDirect::Request';
    my $xcpt = 'RPC::ExtDirect::Exception';

    # Try to decode data, return Exception upon failure
    my $data = eval { decode_json $post_text };

    if ( $@ ) {
        my $error = RPC::ExtDirect::Exception->clean_message($@);

        my $msg = "ExtDirect error decoding POST data: '$error'";
        return [ $xcpt->new({ debug => $DEBUG, message => $msg }) ];
    };

    # Normalize data
    $data = [ $data ] unless ref $data eq 'ARRAY';

    # Create array of Requests (or Exceptions)
    my @requests = map { $rqst->new($_) } @$data;

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
    my $request = RPC::ExtDirect::Request->new($form_hashref);

    return [ $request ];
}

############## PRIVATE METHODS BELOW ##############

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Deserialize - Handles JSON Ext.Direct requests

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 DEPENDENCIES

RPC::ExtDirect::Deserialize is dependent on the following modules:
    JSON

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
