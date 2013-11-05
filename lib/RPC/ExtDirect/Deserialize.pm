#
# WARNING: This package is deprecated.
#
# See RPC::ExtDirect::Serializer perldoc for the description
# of the instance-based configuration options to be used instead
# of the former global variables in this package.
#

package RPC::ExtDirect::Deserialize;

use strict;
use warnings;

### PACKAGE GLOBAL VARIABLE ###
#
# Set it to true value to turn on debugging
# DEPRECATED
#

our $DEBUG;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
# DEPRECATED
#

our $EXCEPTION_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Request class name so it could be configured
# DEPRECATED
#

our $REQUEST_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# JSON decoding options
# DEPRECATED
#

our %JSON_OPTIONS;

############## PRIVATE METHODS BELOW ##############

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Deserialize - DEPRECATED

=head1 SYNOPSIS

This module is deprecated. See L<RPC::ExtDirect::Serializer> for description
of the instance-based configuration options used instead of the former
global variables in this module.

=head1 AUTHOR

Alex Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2013 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
