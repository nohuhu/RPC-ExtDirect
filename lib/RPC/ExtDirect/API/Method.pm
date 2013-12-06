package RPC::ExtDirect::API::Method;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use RPC::ExtDirect::Config;
use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (ACCESSOR) ###
#
# Return the hook types supported by this Method class
#

sub HOOK_TYPES { qw/ before instead after / }

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new Method
#

sub new {
    my ($class, $method) = @_;
    
    return bless {
        %$method,
        is_named   => defined $method->{params},
        is_ordered => defined $method->{len},
    }, $class;
}

### PUBLIC INSTANCE METHOD ###
#
# Return a hashref with API definition for this Method
#

sub get_api_definition {
    my ($self) = @_;
    
    # Poll handlers are not declared in the API
    return if $self->pollHandler;
    
    # Form handlers are defined like this
    # (\1 means JSON::true and doesn't force us to `use JSON`)
    return { name => $self->name, len => 0, formHandler => \1 }
        if $self->formHandler;
    
    # Ordinary method with positioned arguments
    return { name => $self->name, len => $self->len + 0 },
        if $self->is_ordered;
    
    # Ordinary method with named arguments
    return { name => $self->name, params => $self->params }
        if $self->params;
    
    # No arguments specified means we're not checking them
    return { name => $self->name };
}

### PUBLIC INSTANCE METHOD ###
#
# Return a hashref with backwards-compatible API definition
# for this Method
#

sub get_api_definition_compat {
    my ($self) = @_;
    
    my %attrs;
    
    $attrs{package}     = $self->package;
    $attrs{method}      = $self->name;
    $attrs{param_names} = $self->params;
    $attrs{param_no}    = $self->len;
    $attrs{pollHandler} = $self->pollHandler || 0;
    $attrs{formHandler} = $self->formHandler || 0;
    $attrs{param_no}    = undef if $attrs{formHandler};
    
    for my $type ( $self->HOOK_TYPES ) {
        my $hook = $self->$type;
        
        $attrs{$type} = $hook->code if $hook;
    }
    
    return %attrs;
}

### PUBLIC INSTANCE METHOD ###
#
# Return a reference to the actual code for this Method
#

sub code {
    my ($self) = @_;
    
    my $package = $self->package;
    my $name    = $self->name;
    
    eval "require $package";
    
    no strict 'refs';
    
    return *{ $package . '::' . $name }{CODE};
}

### PUBLIC INSTANCE METHODS ###
#
# Read-write accessors
#

my $accessors = [qw/
    config
    action
    name
    params
    len
    formHandler
    pollHandler
    is_ordered
    is_named
    package
/,
    __PACKAGE__->HOOK_TYPES,
];

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => $accessors,
);

1;
