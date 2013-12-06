package RPC::ExtDirect::Util;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Carp;

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
        my $fields  = $flag->{setter};
        my $default = $flag->{default};
        
        my $have_default = exists $flag->{default};
        my $full_var     = $package . '::' . $var;
        
        my ($value, $have_value);
        
        {
            no strict   'refs';
            no warnings 'once';
            
            if ( $type eq 'scalar' ) {
                $have_value = defined ${ $full_var };
                $value      = $have_value ? ${ $full_var } : $default;
            }
            elsif ( $type eq 'hash' ) {
                $have_value = %{ $full_var };
                $value      = $have_value            ? { %{ $full_var } }
                            : 'HASH' eq ref $default ? { %$default      }
                            :                          undef
                            ;
            }
            elsif ( $type eq 'array' ) {
                $have_value = @{ $full_var };
                $value      = $have_value             ? [ @{ $full_var } ]
                            : 'ARRAY' eq ref $default ? [ @$default      ]
                            :                           undef
                            ;
            }
            else {
                die "Unknown global variable type: '$type'"; # Debug mostly
            }
        }
        
        if ( $have_value ) {
            my $warning = <<"END";

The package global variable $full_var is deprecated
and is going to be removed in the next RPC::ExtDirect version.
END
            
            if ( 'ARRAY' eq ref $fields ) {
                
                my $tpl = <<"END";
Use $caller_pkg instance with the following config options instead:
%s

    my \$config = $caller_pkg->new(
%s
    );

END
                my $w1 = join ', ', map { "`$_`" } @$fields;
                my $w2 = join "\n", map { "\t\t$_ => ..." } @$fields;
                
                $warning .= sprintf $tpl, $w1, $w2;
            }
            else {
                $warning .= <<"END";
Use the `$fields` config option with the $caller_pkg
instance instead:

    my \$config = $caller_pkg->new(
            $fields => ...
    );
    
END
            }
            
            warn $warning;
        }

        croak "Can't resolve the field name for var $full_var"
            unless $fields;
        
        $fields = [ $fields ] unless 'ARRAY' eq ref $fields;
        
        for my $field ( @$fields ) {
            my $predicate = "has_$field";
        
            $obj->$field($value)
                if $have_value || ($have_default && !$obj->$predicate());
        }
    }
}

### PUBLIC PACKAGE SUBROUTINE ###
#
# Parse ExtDirect attribute, perform sanity checks and return
# the attribute hashref
#

sub parse_attribute {
    my ($package, $symbol, $referent, $attr, $data, $phase, $file, $line)
        = @_;

    croak "Method attribute is not ExtDirect at $file line $line"
        unless $attr eq 'ExtDirect';

    my $symbol_name = eval { no strict 'refs'; *{$symbol}{NAME} };
    croak "Can't resolve symbol '$symbol' for package '$package' ".
          "at $file line $line: $@"
        if $@;

    # These parameters depend on attribute input
    my $param_no    = undef;
    my $param_names = undef;
    my $formHandler = !1;
    my $pollHandler = !1;
    my %hooks       = ();
    $data           = $data || [];

    while ( @$data ) {
        my $param_def = shift @$data;

        # Digits means number of unnamed arguments
        if ( $param_def =~ / \A (\d+) \z /xms ) {
            $param_no = $1;
        }

        # formHandler means exactly that, a handler for form requests
        elsif ( $param_def =~ / \A formHandler \z /xms ) {
            $formHandler = 1;
        }

        # pollHandlers are a bit tricky but are defined here anyway
        elsif ( $param_def =~ / \A pollHandler \z /xms ) {
            $pollHandler = 1;
        }

        elsif ( $param_def =~ / \A params \z /ixms ) {
            my $arg_names = shift @$data;

            croak "ExtDirect attribute 'params' must be followed by ".
                  "arrayref containing at least one parameter name ".
                  "at $file line $line"
                if ref $arg_names ne 'ARRAY' || @$arg_names < 1;

            # Copy the names
            $param_names = [ @{ $arg_names } ];
        }

        # Hooks
        elsif ( $param_def =~ / \A (before|instead|after) \z /ixms ) {
            my $type = $1;
            my $code = shift @$data;

            croak "ExtDirect attribute '$type' must be followed by coderef ".
                  "or 'NONE' at $file line $line"
                if $code ne 'NONE' && 'CODE' ne ref $code;

            $hooks{ $type } = {
                type => $type,
                code => $code,
            };
        };
    };

    my $attribute_ref = {
        package     => $package,
        method      => $symbol_name,
        referent    => $referent,
        param_no    => $param_no,
        param_names => $param_names,
        formHandler => $formHandler,
        pollHandler => $pollHandler,
    };

    @$attribute_ref{ keys %hooks } = values %hooks;
    
    return $attribute_ref;
}

1;
