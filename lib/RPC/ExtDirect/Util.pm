package RPC::ExtDirect::Util;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use base 'Exporter';

our @EXPORT_OK = qw/
    clean_error_message
    get_caller_info
    parse_global_flags
/;

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

### PUBLIC PACKAGE SUBROUTINE ###
#
# Return formatted call stack part to use in exception
#

sub get_caller_info {
    my ($depth) = @_;
    
    my ($package, $sub) = (caller $depth)[3] =~ / \A (.*) :: (.*?) \z /xms;
    
    return $package . '->' . $sub;
}

### PUBLIC PACKAGE SUBROUTINE ###
#
# Fetch the values of the (deprecated) global flags,
# giving a warning when they're used
#

sub parse_global_flags {
    my ($flags, $obj) = @_;
    
    my $caller_pkg = caller;
    
    for my $flag ( @$flags ) {
        my $package = $flag->{package};
        my $var     = $flag->{var};
        my $type    = $flag->{type};
        my $field   = $flag->{field};
        my $default = $flag->{default};
        
        my $full_var = $package . '::' . $var;
        
        my ($value, $have_value);
        
        {
            no strict 'refs';
            
            if ( $type eq 'scalar' ) {
                $have_value = defined ${ $full_var };
                $value      = $have_value ? ${ $full_var } : $default;
            }
            elsif ( $type eq 'hash' ) {
                $have_value = %{ $full_var };
                $value      = $have_value ? { %{ $full_var } } : {%$default};
            }
            elsif ( $type eq 'array' ) {
                $have_value = @{ $full_var };
                $value      = $have_value ? [ @{ $full_var } ] : [@$default];
            }
            else {
                die "Unknown global variable type: '$type'"; # Debug mostly
            }
        }
        
        if ( $have_value ) {
            warn <<END;
The package global variable $full_var is deprecated
and is going to be removed in the next RPC::ExtDirect version.
Use the `$field` config option with the $caller_pkg
instance instead:

    my \$obj = $caller_pkg->new(
            $field => ...
    );
    
END
        }
        
        $obj->$field($value) unless defined $obj->$field();
    }
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
