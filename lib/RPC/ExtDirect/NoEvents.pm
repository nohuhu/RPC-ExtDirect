package RPC::ExtDirect::NoEvents;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use base 'RPC::ExtDirect::Event';

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of NoEvents.
#

sub new {
    my ($class) = @_;

    return $class->SUPER::new('__NONE__', '');
}

############## PRIVATE METHODS BELOW ##############

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::NoEvents - Something to return when there is nothing to give back

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 DESCRIPTION

This module provides a stub Event that EventProvider must return when there
are no events returned by handlers. ExtJS implementation does not allow for
none events returned at all so we have to return something - which is
NoEvents.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.
