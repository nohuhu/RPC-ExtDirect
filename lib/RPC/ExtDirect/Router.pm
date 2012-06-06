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

### PUBLIC CLASS METHOD ###
#
# Routes the request(s) and returns serialized responses
#

sub route {
    my ($class, $input) = @_;

    # Set debug flags
    local $RPC::ExtDirect::Deserialize::DEBUG = $DEBUG;
    local $RPC::ExtDirect::Serialize::DEBUG   = $DEBUG;
    local $RPC::ExtDirect::Exception::DEBUG   = $DEBUG;
    local $RPC::ExtDirect::Request::DEBUG     = $DEBUG;

    # Shortcuts
    my $ser   = 'RPC::ExtDirect::Serialize';
    my $deser = 'RPC::ExtDirect::Deserialize';

    # $input can be scalar containing POST data,
    # or a hashref containing form data
    my $has_form   = ref $input eq 'HASH';
    my $has_upload = $has_form && $input->{extUpload} eq 'true';

    my $requests = $has_form ? $deser->decode_form($input)
                 :             $deser->decode_post($input)
                 ;

    # Run the requests
    $_->run() for @$requests;

    # Collect responses
    my $responses = [ map { $_->result() } @$requests ];

    # Serialize responses
    my $result = $ser->serialize(@$responses);

    # Wrap in HTML if that was form request
    $result = _wrap_in_html($result) if $has_upload;

    # Form responses are HTML instead of JSON
    my $content_type = $has_upload ? 'text/html' : 'application/json';

    return [ $content_type, $result ];
}

############## PRIVATE METHODS BELOW ##############

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

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
