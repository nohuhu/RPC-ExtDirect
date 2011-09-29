package RPC::ExtDirect::Config;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

### PUBLIC PACKAGE VARIABLE ###
#
# Version of this module.
#

our $VERSION = '1.00';

### PUBLIC CLASS METHOD ###
#
# Returns default router path
#

sub get_router_path { '/extdirectrouter' }

### PUBLIC CLASS METHOD ###
#
# Returns polling (events) path
#

sub get_poll_path { '/extdirectevents' }

### PUBLIC CLASS METHOD ###
#
# Returns REMOTING_API variable name
#

sub get_remoting_var { 'Ext.app.REMOTING_API' }

### PUBLIC CLASS METHOD ###
#
# Returns POLLING_API variable name (RPC::ExtDirect extension)

sub get_polling_var { 'Ext.app.POLLING_API' }

############## PRIVATE METHODS BELOW ##############

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Config - Default options for ExtDirect API

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 DESCRIPTION

This module should be subclassed by implementations of particular
Web environment gateways to provide reasonable defaults.

=head1 SUBROUTINES/METHODS

No subroutines exported by default. None are expected to be called directly.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.
