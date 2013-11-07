package RPC::ExtDirect::Util::Accessor;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

### PRIVATE PACKAGE SUBROUTINE ###
#
# Generate simple accessors for the passed list of properties,
# with each accessor acting as both getter and setter.
#

sub create_accessors {
    my (%params) = @_;
    
    my $caller_class = caller();
    
    no strict 'refs';
    
    my $simple = $params{accessors} || $params{simple};
    
    for my $prop ( @$simple ) {
        *{ $caller_class . '::' . $prop }
            = _simple_accessor($caller_class, $prop);
    }
    
    my $defaultable = $params{defaultable} || $params{complex};
    
    for my $prop ( @$defaultable ) {
        my $specific = $prop->{specific};
        my $fallback = $prop->{fallback};
        my $method   = $caller_class . '::' . $specific;
        
        *{ $method }
            = _defaultable_accessor($caller_class, $specific, $fallback);
    }
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE PACKAGE SUBROUTINE #
#
# Return a simple accessor method that acts as both getter when there
# are no arguments passed to it, and as a setter when there is at least
# one argument.
# When used as a setter, only the first argument will be assigned
# to the object property, the rest will be ignored.
#

sub _simple_accessor {
    my ($caller_class, $prop) = @_;
    
    return
        sub { 
            my $self = shift;
            
            if ( @_ ) {
                $self->{$prop} = shift;
                return $self;
            }
            else {
                return $self->{$prop};
            }
        };
}

### PRIVATE PACKAGE SUBROUTINE ###
#
# Return an accessor that will query the 'specific' object property
# first and return it if it's defined, falling back to the 'default'
# property getter otherwise when called with no arguments.
# Setter will set the 'specific' property for the object when called
# with one argument.
#

sub _defaultable_accessor {
    my ($caller_class, $specific, $default) = @_;
    
    return
        sub {
            my $self = shift;
            
            if ( @_ ) {
                $self->{$specific} = shift;
                return $self;
            }
            else {
                my $value = $self->{$specific};
                return defined $value ? $value : $self->$default();
            }
        };
}

1;
