package RPC::ExtDirect::Hook;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use B;
use Carp;

use RPC::ExtDirect ();

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate new Hook object
#

sub new {
    my ($class, $type, $method_def) = @_;

    my $package = $method_def->{package};
    my $method  = $method_def->{method};

    my ($before, $instead, $after)
        = map {
                    RPC::ExtDirect->get_hook(
                        type    => $_,
                        package => $package,
                        method  => $method,
                    )
              }
              qw/ before instead after/;

    my $self = bless {}, $class;

    @$self{ qw/type   method_def   before   instead   after/ }
        = (   $type, $method_def, $before, $instead, $after  );

    return $self->hook ? $self : undef
}

### PUBLIC INSTANCE METHOD ###
#
# Run the hook
#

sub run {
    my ($self, $env, $arg, $result, $exception, $method_called) = @_;

    my %hook_arg = %{ $self->method_def };

    $hook_arg{code} = delete $hook_arg{referent};

    my @param_names = @{ $hook_arg{param_names} || [] };

    $hook_arg{arg} = $arg;
    $hook_arg{env} = $env;

    # Result and exception are passed to "after" hook only
    @hook_arg{ qw/result   exception   method_called/ }
              = ($result, $exception, $method_called)
        if $self->type eq 'after';

    @hook_arg{ qw/before instead after/ }
        = map { $self->$_ } qw/before instead after/;

    # A drop of sugar
    $hook_arg{orig} = sub {
        my $code    = $hook_arg{code};
        my $package = $hook_arg{package};

        return $code->($package, @$arg);
    };

    my $hook     = $self->hook;
    my $hook_pkg = _package_from_coderef($hook);

    # By convention, hooks are called as class methods
    return $hook->($hook_pkg, %hook_arg);
}

### PUBLIC INSTANCE METHODS ###
#
# Read only getters
#

sub type       { shift->{type}       }
sub before     { shift->{before}     }
sub instead    { shift->{instead}    }
sub after      { shift->{after}      }
sub method_def { shift->{method_def} }

sub hook    {
    my ($self) = @_;

    my $type = $self->type;

    return $self->$type;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE PACKAGE SUBROUTINE ###
#
# Return package name from coderef
#

sub _package_from_coderef {
    my ($code) = @_;

    my $pkg = eval { B::svref_2object($code)->GV->STASH->NAME };

    return defined $pkg && $pkg ne '' ? $pkg : undef;
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Hook - Implements Ext.Direct method hooks

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

