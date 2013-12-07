package RPC::ExtDirect::Util::Accessor;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

### PRIVATE PACKAGE SUBROUTINE ###
#
# Generate either simple accessors, or complex ones, or both
#

sub mk_accessors {
    my (%params) = @_;
    
    my $caller_class = caller();
    
    my $simplexes = $params{simple};
    
    for my $prop ( @$simplexes ) {
        my $accessor  = _simple_accessor($prop);
        my $predicate = _predicate($prop);
        
        eval "package $caller_class; $accessor; $predicate; 1";
    }
    
    my $complexes = $params{complex};
    
    for my $prop ( @$complexes ) {
        my $setters  = $prop->{setter};
        my $fallback = $prop->{fallback};
        
        $setters = [ $setters ] unless 'ARRAY' eq ref $setters;
        
        for my $specific ( @$setters ) {
            my $accessor  = _complex_accessor($specific, $fallback);
            my $predicate = _predicate($specific);
        
            eval "package $caller_class; no warnings 'redefine'; " .
                 "$accessor; $predicate; 1";
        }
    }
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE PACKAGE SUBROUTINE ###
#
# Return the text for a predicate method
#

sub _predicate {
    my ($prop) = @_;
    
    return "
        sub has_$prop {
            my \$self = shift;
            
            return exists \$self->{$prop};
        }
    ";
}

### PRIVATE PACKAGE SUBROUTINE ###
#
# Return the text for a simple accessor method that acts as both getter
# when there are no arguments passed to it, and as a setter when there is
# at least one argument.
# When used as a setter, only the first argument will be assigned
# to the object property, the rest will be ignored.
#

sub _simple_accessor {
    my ($prop) = @_;
    
    return "
        sub $prop { 
            my \$self = shift;
            
            if ( \@_ ) {
                \$self->{$prop} = shift;
                return \$self;
            }
            else {
                return \$self->{$prop};
            }
        }
    ";
}

### PRIVATE PACKAGE SUBROUTINE ###
#
# Return an accessor that will query the 'specific' object property
# first and return it if it's defined, falling back to the 'fallback'
# property getter otherwise when called with no arguments.
# Setter will set the 'specific' property for the object when called
# with one argument.
#

sub _complex_accessor {
    my ($specific, $fallback) = @_;
    
    return "
        sub $specific {
            my \$self = shift;
            
            if ( \@_ ) {
                \$self->{$specific} = shift;
                return \$self;
            }
            else {
                return exists \$self->{$specific}
                            ? \$self->{$specific}
                            : \$self->$fallback()
                            ;
            }
        }
    ";
}

1;
