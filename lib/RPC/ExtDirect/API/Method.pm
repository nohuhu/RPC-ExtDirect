package RPC::ExtDirect::API::Method;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use RPC::ExtDirect::Config;
use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect::API::Hook;

### PUBLIC CLASS METHOD (ACCESSOR) ###
#
# Return the hook types supported by this Method class
#

sub HOOK_TYPES { qw/ before instead after / }

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new Method object
#

sub new {
    my ($class, $method_def) = @_;
    
    my $pollHandler = $method_def->{pollHandler};
    my $formHandler = $method_def->{formHandler};
    
    my $is_named
        = defined $method_def->{params} && !$pollHandler && !$formHandler;
    
    my $is_ordered
        = defined $method_def->{len} && !$pollHandler && !$formHandler;
    
    return bless {
        %$method_def,
        is_named   => $is_named,
        is_ordered => $is_ordered,
    }, $class;
}

### PUBLIC INSTANCE METHOD ###
#
# Return a hashref with the API definition for this Method,
# or an empty list
#

sub get_api_definition {
    my ($self, $env) = @_;
    
    # By default we're not using the environment object,
    # but user can override this method to make permission
    # and/or other kind of checks
    
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

### PUBLIC INSTANCE METHOD ###
#
# Run the Method code using the provided Environment object
# and input data; return the result or die with exception
#
# We accept named parameters here to keep the signature compatible
# with the corresponding Hook method
#

sub run {
    my ($self, %args) = @_;
    
    my $arg     = $args{arg};
    my $package = $self->package;
    my $code    = $self->code;
    
    # pollHandler methods should always be called in the list context
    if ( $self->pollHandler ) {
        return [ $code->($package, @$arg) ];
    }
    else {
        return $code->($package, @$arg);
    }
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments to be passed to the called Method,
# according to the Method's expectations
#

sub prepare_method_arguments {
    my $self = shift;
    
    my $preparer = $self->pollHandler ? "prepare_pollHandler_arguments"
                 : $self->formHandler ? "prepare_formHandler_arguments"
                 : $self->params      ? "prepare_named_arguments"
                 : defined $self->len ? "prepare_ordered_arguments"
                 :                      "prepare_default_arguments"
                 ;
    
    return $self->$preparer(@_);
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments for a pollHandler
#

sub prepare_pollHandler_arguments {
    my ($self, %arg) = @_;
    
    return ( $arg{env} );
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments for a formHandler
#

sub prepare_formHandler_arguments {
    my ($self, %arg) = @_;
    
    my $env    = $arg{env};
    my $input  = $arg{input};
    my $upload = $arg{upload};
    
    # Data should be a hashref here
    my %data = %$input;

    # Ensure there are no runaway ExtDirect form parameters
    my @runaway_params = qw(action method extAction extMethod
                            extTID extUpload _uploads);
    delete @data{ @runaway_params };

    # Add uploads if there are any
    $data{file_uploads} = $upload if $upload;

    $data{_env} = $env;

    return %data;
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments for a Method with named parameters
#

sub prepare_named_arguments {
    my ($self, %arg) = @_;
    
    my $env   = $arg{env};
    my $input = $arg{input};
    
    my %data  = %$input;
    my @names = @{ $self->params };
    my %actual_arg;
    
    @actual_arg{ @names } = @data{ @names };
    $actual_arg{_env} = $env;

    return %actual_arg;
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments for a Method with ordered parameters
#

sub prepare_ordered_arguments {
    my ($self, %arg) = @_;
    
    my $env   = $arg{env};
    my $input = $arg{input};
    
    my @data = @$input;
    my @arg  = splice @data, 0, $self->len;

    push @arg, $env;
    
    return @arg;
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments when the Method signature is unknown
#

sub prepare_default_arguments {
    my ($self, %arg) = @_;
    
    return ( $arg{input}, $arg{env} );
}

### PUBLIC INSTANCE METHODS ###
#
# Simple read-write accessors
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
