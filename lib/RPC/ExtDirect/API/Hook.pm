package RPC::ExtDirect::API::Hook;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use B;

use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate new Hook object
#

sub new {
    my ($class, %params) = @_;
    
    my ($type, $coderef) = @params{qw/ type code /};
    my $package = _package_from_coderef($coderef);
    
    return undef if 'NONE' eq $coderef || !defined $package;
    
    my $self = bless {
        package => $package,
        type    => $type,
        code    => $coderef,
    }, $class;
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Run the hook
#

sub run {
    my ($self, %params) = @_;
    
    my            ($api, $env, $arg, $result, $exception, $method_called) =
        @params{qw/ api   env   arg   result   exception   method_called /};
    
    my $action_name = $self->action;
    my $method_name = $self->method;
    
    my $method   = $api->get_method_by_name($action_name, $method_name);
    my %hook_arg = $method->get_api_definition_compat();
    
    my $method_package = $hook_arg{package};
    my $method_coderef = $hook_arg{code} = eval {
        no strict 'refs';
        *{ $method_package . '::' . $method_name }
    };

    my @param_names = @{ $hook_arg{param_names} || [] };

    $hook_arg{arg} = $arg;
    $hook_arg{env} = $env;

    # Result and exception are passed to "after" hook only
    @hook_arg{ qw/result   exception   method_called/ }
              = ($result, $exception, $method_called)
        if $self->type eq 'after';

    @hook_arg{ qw/before instead after/ }
        = map {
            $api->get_hook(
                action => $action_name,
                method => $method_name,
                type   => $_,
            )
        } qw/before instead after/;

    # A drop of sugar
    $hook_arg{orig} = sub { $method_coderef->($method_package, @$arg) };

    my $hook_coderef = $self->code;
    my $hook_pkg     = $self->package;

    # By convention, hooks are called as class methods
    return $hook_coderef->($hook_pkg, %hook_arg);
}

### PUBLIC INSTANCE METHODS ###
#
# Read only getters
#

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => [qw/ type code package /],
);

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
