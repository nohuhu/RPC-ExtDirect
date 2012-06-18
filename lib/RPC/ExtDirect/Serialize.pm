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

### PUBLIC CLASS METHOD ###
#
# Serializes the data passed to it in JSON
#

sub serialize {
    my ($class, $suppress_exceptions, @data) = @_;

    my $json = JSON->new->utf8->canonical($DEBUG);

    # Try to serialize each response separately;
    # if one fails it's better to return an exception
    # for one response than fail all of them
    my @serialized;
    for my $response ( @data ) {
        my $text = eval { $json->encode($response) };

        if ( $@ and not $suppress_exceptions ) {
            my $msg = RPC::ExtDirect::Exception->clean_message($@);

            my $exception = RPC::ExtDirect::Exception->new({
                                debug   => $DEBUG,
                                action  => $response->{action},
                                method  => $response->{method},
                                tid     => $response->{tid},
                                where   => __PACKAGE__,
                                message => $msg,
                             });
            $text = eval { $json->encode( $exception->result() ) };
        };

        push @serialized, $text;
    };

    my $text = @serialized == 1 ? shift @serialized
             :                    '[' . join(',', @serialized) . ']'
             ;

    return $text;
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

RPC::ExtDirect::Serialize is dependent on the following modules: L<JSON>.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

