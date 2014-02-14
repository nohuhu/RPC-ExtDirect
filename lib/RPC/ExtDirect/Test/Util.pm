package RPC::ExtDirect::Test::Util;

use strict;
use warnings;
no  warnings 'uninitialized';

use base 'Exporter';

use Test::More;

our @EXPORT = qw/
    is_deep
    deparse_api
/;

### EXPORTED PUBLIC PACKAGE SUBROUTINE ###
#
# A wrapper around Test::More::is_deeply() that will print
# the diagnostics if a test fails
#

sub is_deep {
    is_deeply @_ or diag explain "Expected: ", $_[1], "Actual: ", $_[0];
}

### EXPORTED PUBLIC PACKAGE SUBROUTINE ###
#
# Deparse and normalize a JavaScript string with Ext.Direct API
# declaration into Perl data structures suitable for deep comparison
#

sub deparse_api {
    my ($api_str) = @_;
    
    $api_str =~ s/\s*//gms;

    my @parts = split /;\s*/, $api_str;

    for my $part ( @parts ) {
        next unless $part =~ /={/;

        my ($var, $json) = split /=/, $part;
        
        my $api_def = JSON::from_json($json);
        
        $api_def->{actions} = sort_action_methods($api_def->{actions});

        $part = { $var => $api_def };
    }

    return [ @parts ];
}

### NON EXPORTED PUBLIC PACKAGE SUBROUTINE ###
#
# Sort the Method hashrefs on an Action object
#

sub sort_action_methods {
    my ($api_href) = @_;
    
    my $new_href = {};
    
    # map() looks too unwieldy here
    for my $action_name ( keys %$api_href ) {
        my @methods = @{ $api_href->{ $action_name } };
        
        $new_href->{ $action_name }
            = [ sort { $a->{name} cmp $b->{name} } @methods ];
    }
    
    return $new_href;
}

1;

