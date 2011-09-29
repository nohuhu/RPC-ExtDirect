package RPC::ExtDirect::Serialize;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use JSON;

### PACKAGE GLOBAL VARIABLE ###
#
# Version of this module.
#

our $VERSION = '1.00';

### PACKAGE GLOBAL VARIABLE ###
#
# Turn on for debugging
#

our $DEBUG = 0;

### PUBLIC CLASS METHOD ###
#
# Serializes the data passed to it in JSON
#

sub serialize {
    my ($class, @data) = @_;

    # Single parameter comes through, else wrap
    my $data_ref = @data == 1 ?   $data[0]
                 :              [ @data    ]
                 ;

    my $json      = JSON->new->utf8->canonical($DEBUG);
    my $json_text = $json->encode( $data_ref );

    return $json_text;
}

############## PRIVATE METHODS BELOW ##############

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Serialize - Provides data serialization into JSON

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 DEPENDENCIES

RPC::ExtDirect::Serialize is dependent on the following modules:
    JSON

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
