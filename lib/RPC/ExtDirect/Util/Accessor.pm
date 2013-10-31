package RPC::ExtDirect::Util::Accessor;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

### PUBLIC PACKAGE SUBROUTINE ###
#
# Generate accessors for the list of properties passed in.
#

sub import {
    my ($class, @properties) = @_;
    
    return unless @properties;
    
    my $caller_class = caller();
    
    no strict 'refs';
    
    for my $prop ( @properties ) {
        *{ $caller_class . '::' . $prop } = sub { $_[0]->{$prop} };
    }
}

############## PRIVATE METHODS BELOW ##############

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Util::Accessor - Accessorize the classes

=head1 SYNOPSIS

This module is not intended to be used directly.

However if you want to, there's no stopping you:

    package Foo;
    
    use RPC::ExtDirect::Util::Accessor qw/ foo bar /;
    
    my $foo = Foo->new();
    
    print $foo->foo(), $foo->bar();

=head1 AUTHOR

Alex Tokarev E<lt>tokarev@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2013 Alex Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
