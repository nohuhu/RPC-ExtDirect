package RPC::ExtDirect::Util;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

### PUBLIC PACKAGE SUBROUTINE ###
#
# Clean croak() and die() messages of file/line information
#

sub clean_error_message {
    my ($msg) = @_;

    $msg =~ s/
        (?<![,]) \s
        at
        .*?
        line \s \d+(, \s <DATA> \s line \s \d+)? \.? \n*
        (?:\s*eval \s {...} \s called \s at \s .*? line \s \d+ \n*)?
        //msx;

    return $msg;
}

### PUBLIC CLASS METHOD ###
#
# Return formatted call stack part to use in exception
#

sub get_caller_info {
    my ($depth) = @_;
    
    my ($package, $sub) = (caller $depth)[3] =~ / \A (.*) :: (.*?) \z /xms;
    
    return $package . '->' . $sub;
}

############## PRIVATE METHODS BELOW ##############

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Util - Utility functions for RPC::ExtDirect

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 AUTHOR

Alex Tokarev E<lt>tokarev@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2013 Alex Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
