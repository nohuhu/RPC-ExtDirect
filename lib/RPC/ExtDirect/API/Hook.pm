package RPC::ExtDirect::API::Hook;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use B;

use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (ACCESSOR) ###
#
# Return the list of supported hook types
#

sub HOOK_TYPES { qw/ before instead after / }

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new Hook object
#

sub new {
    my ($class, %arg) = @_;
    
    my ($type, $coderef) = @arg{qw/ type code /};
    my $package = _package_from_coderef($coderef);
    
    my $self = bless {
        package  => $package,
        type     => $type,
        code     => $coderef,
        runnable => 'CODE' eq ref $coderef,
    }, $class;
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Run the hook
#

sub run {
    my ($self, %args) = @_;
    
    my ($api, $env, $arg, $result, $exception, $method_ref, $callee)
        = @args{qw/api env arg result exception method_ref callee/};
    
    my $action_name    = $method_ref->action;
    my $method_name    = $method_ref->name;
    my $method_pkg     = $method_ref->package;
    my $method_coderef = $method_ref->code;
    
    my %hook_arg = $method_ref->get_api_definition_compat();

    $hook_arg{arg}  = $arg;
    $hook_arg{env}  = $env;
    $hook_arg{code} = $method_coderef;

    # Result and exception are passed to "after" hook only
    @hook_arg{ qw/result   exception   method_called/ }
              = ($result, $exception, $callee)
        if $self->type eq 'after';

    for my $type ( $self->HOOK_TYPES ) {
        my $hook = $api->get_hook(
            action => $action_name,
            method => $method_name,
            type   => $type,
        );
        
        $hook_arg{ $type } = $hook ? $hook->code : undef;
    }

    # A drop of sugar
    $hook_arg{orig} = sub { $method_coderef->($method_pkg, @$arg) };

    my $hook_coderef = $self->code;
    my $hook_pkg     = $self->package;

    # By convention, hooks are called as class methods
    return $hook_coderef->($hook_pkg, %hook_arg);
}

### PUBLIC INSTANCE METHODS ###
#
# Simple read-write accessors
#

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => [qw/ type code package runnable /],
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
