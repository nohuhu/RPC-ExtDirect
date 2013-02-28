package RPC::ExtDirect::Router;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Carp;

use RPC::ExtDirect::Deserialize;
use RPC::ExtDirect::Serialize;
use RPC::ExtDirect::Request;
use RPC::ExtDirect::Exception;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn this on for debug output
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
# Set Deserializer class name so it could be configured
#

our $DESERIALIZER_CLASS = 'RPC::ExtDirect::Deserialize';

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

### PUBLIC CLASS METHOD ###
#
# Routes the request(s) and returns serialized responses
#

sub route {
    my ($class, $input, $env) = @_;

    #
    # It's a bit awkward to turn this off for the whole sub,
    # but enclosing `local` in a block won't work
    #
    no strict 'refs';       ## no critic

    # Set debug flags
    local ${$DESERIALIZER_CLASS.'::DEBUG'} = $DEBUG;
    local ${$SERIALIZER_CLASS.'::DEBUG'}   = $DEBUG;
    local ${$EXCEPTION_CLASS.'::DEBUG'}    = $DEBUG;
    local ${$REQUEST_CLASS.'::DEBUG'}      = $DEBUG;
    
    # Propagate class names
    local ${$DESERIALIZER_CLASS.'::REQUEST_CLASS'}   = $REQUEST_CLASS;
    local ${$DESERIALIZER_CLASS.'::EXCEPTION_CLASS'} = $EXCEPTION_CLASS;
    local ${$SERIALIZER_CLASS.'::EXCEPTION_CLASS'}   = $EXCEPTION_CLASS;
    local ${$REQUEST_CLASS.'::EXCEPTION_CLASS'}      = $EXCEPTION_CLASS;
    
    # Decode requests
    my ($has_upload, $requests) = $class->_decode_requests($input);

    # Run requests and collect responses
    my $responses = $class->_run_requests($env, $requests);

    # Serialize responses
    my $result = $class->_serialize_responses($responses);

    my $http_response = $class->_format_response($result, $has_upload);
    
    return $http_response;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Decode requests
#

sub _decode_requests {
    my ($class, $input) = @_;
    
    # $input can be scalar containing POST data,
    # or a hashref containing form data
    my $has_form   = ref $input eq 'HASH';
    my $has_upload = $has_form && $input->{extUpload} eq 'true';

    my $requests = $has_form ? $DESERIALIZER_CLASS->decode_form($input)
                 :             $DESERIALIZER_CLASS->decode_post($input)
                 ;
    
    return ($has_upload, $requests);
}

### PRIVATE INSTANCE METHOD ###
#
# Run the requests and return their results
#

sub _run_requests {
    my ($class, $env, $requests) = @_;
    
    # Run the requests
    $_->run($env) for @$requests;

    # Collect responses
    my $responses = [ map { $_->result() } @$requests ];
    
    return $responses;
}

### PRIVATE INSTANCE METHOD ###
#
# Serialize the responses and return result
#

sub _serialize_responses {
    my ($class, $responses) = @_;

    my $result = $SERIALIZER_CLASS->serialize(0, @$responses);
    
    return $result;
}

### PRIVATE INSTANCE METHOD ###
#
# Format Plack-compatible HTTP response
#

sub _format_response {
    my ($class, $result, $has_upload) = @_;
    
    # Wrap in HTML if that was form upload request
    $result = _wrap_in_html($result) if $has_upload;

    # Form upload responses are JSON wrapped in HTML, not plain JSON
    my $content_type = $has_upload ? 'text/html' : 'application/json';

    # We need content length in octets
    my $content_length = do { no warnings; use bytes; length $result };

    return [
        200,
        [
            'Content-Type',   $content_type,
            'Content-Length', $content_length,
        ],
        [ $result ],
    ];
}

### PRIVATE INSTANCE METHOD ###
#
# Wraps response text in HTML; used with form requests
#

sub _wrap_in_html {
    my ($json) = @_;

    # Actually wrap in soft HTML blankets
    my $html = "<html><body><textarea>$json</textarea></body></html>";

    return $html;
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Router - Ext.Direct request dispatcher

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

