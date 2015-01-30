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
# Instantiate a new Method object
#

sub new {
    my ($class, %arg) = @_;
    
    my $config     = $arg{config};
    my $hook_class = $config->api_hook_class;
    
    my $pollHandler = $arg{pollHandler};
    my $formHandler = $arg{formHandler};
    
    my $is_named
        = defined $arg{params} && !$pollHandler && !$formHandler;
    
    my $is_ordered
        = defined $arg{len} && !$pollHandler && !$formHandler;
    
    my $processor = $pollHandler ? 'pollHandler'
                  : $formHandler ? 'formHandler'
                  : $is_named    ? 'named'
                  : $is_ordered  ? 'ordered'
                  :                'default'
                  ;
    
    # If the Method is named, and params array is empty, force !strict
    if ( $is_named ) {
        $arg{params} = $arg{params} || []; # Better safe than sorry
        $arg{strict} = !1 if !@{ $arg{params} };
    }
    
    # We avoid hard binding on the hook class
    eval "require $hook_class";
    
    my %hooks;
    
    for my $type ( $class->HOOK_TYPES ) {
        my $hook = delete $arg{ $type };
        
        $hooks{ $type } = $hook_class->new( type => $type, code => $hook )
            if $hook;
    }
    
    return bless {
        upload_arg        => 'file_uploads',
        is_named          => $is_named,
        is_ordered        => $is_ordered,
        argument_checker  => "check_${processor}_arguments",
        argument_preparer => "prepare_${processor}_arguments",
        %arg,
        %hooks,
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
    
    my $name   = $self->name;
    my $strict = $self->strict;
    
    # Form handlers are defined like this
    # (\1 means JSON::true and doesn't force us to `use JSON`)
    return { name => $name, len => 0, formHandler => \1 }
        if $self->formHandler;
    
    # Ordinary method with positioned arguments
    return { name => $name, len => $self->len + 0 },
        if $self->is_ordered;
    
    # Ordinary method with named arguments
    return {
        name   => $name,
        params => $self->params,
        defined $strict ? (strict => $strict) : (),
    } if $self->params;
    
    # No arguments specified means we're not checking them
    return { name => $name };
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
    
    return $package->can($name);
}

### PUBLIC INSTANCE METHOD ###
#
# Run the Method code using the provided Environment object
# and input data; return the result or die with exception
#
# We accept named parameters here to keep the signature compatible
# with the corresponding Hook method.
#

sub run {
    my ($self, %args) = @_;
    
    my $arg     = $args{arg};
    my $package = $self->package;
    my $name    = $self->name;
    
    # pollHandler methods should always be called in list context
    return $self->pollHandler ? [ $package->$name(@$arg) ]
         :                        $package->$name(@$arg)
         ;
}

### PUBLIC INSTANCE METHOD ###
#
# Check the arguments that were passed in the Ext.Direct request
# to make sure they conform to the API declared by this Method.
# Arguments should be passed in a reference, either hash- or array-.
# This method is expected to die if anything is wrong, or return 1
# on success.
#
# This method is intentionally split into several submethods,
# instead of using polymorphic subclasses with method overrides.
# Having all these in the same class is easier to maintain and
# augment in user subclasses.
#
# The same applies to `prepare_method_arguments` below.
#

sub check_method_arguments {
    my $self = shift;
    
    my $checker = $self->argument_checker;
    
    return $self->$checker(@_);
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments to be passed to the called Method,
# according to the Method's expectations. This works two ways:
# on the server side, Request will call this method to prepare
# the arguments that are to be passed to the actual Method code
# that does things; on the client side, Client will call this
# method to prepare the arguments that are about to be encoded
# in JSON and passed over to the client side.
#
# The difference is that the server side wants an unfolded list,
# and the client side wants a reference, either hash- or array-.
# Because of that, prepare_*_arguments are context sensitive.
#

sub prepare_method_arguments {
    my $self = shift;
    
    my $preparer = $self->argument_preparer;
    
    return $self->$preparer(@_);
}

### PUBLIC INSTANCE METHOD ###
#
# Check the arguments for a pollHandler
#

sub check_pollHandler_arguments {
    # pollHandlers are not supposed to receive any arguments
    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments for a pollHandler
#

sub prepare_pollHandler_arguments {
    my ($self, %arg) = @_;
    
    my @actual_arg = ();
    
    # When called from the client, env_arg should not be defined
    my $env_arg = $self->env_arg;
    
    no warnings;
    splice @actual_arg, $env_arg, 0, $arg{env} if defined $env_arg;
    
    return wantarray ? @actual_arg : [ @actual_arg ];
}

### PUBLIC INSTANCE METHOD ###
#
# Check the arguments for a formHandler
#

sub check_formHandler_arguments {
    my ($self, $arg) = @_;
    
    # Nothing to check here really except that it's a hashref
    die sprintf "ExtDirect formHandler Method %s.%s expects named " .
                "arguments in hashref\n", $self->action, $self->name
        unless 'HASH' eq ref $arg;
    
    return 1;
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
    
    my $upload_arg = $self->upload_arg;

    # Add uploads if there are any
    $data{ $upload_arg } = $upload if defined $upload;
    
    my $env_arg = $self->env_arg;

    $data{ $env_arg } = $env if $env_arg;

    return wantarray ? %data : { %data };
}

### PUBLIC INSTANCE METHOD ###
#
# Check the arguments for a Method with named parameters
#

sub check_named_arguments {
    my ($self, $arg) = @_;
    
    die sprintf "ExtDirect Method %s.%s expects named arguments " .
                "in hashref\n", $self->action, $self->name
        unless 'HASH' eq ref $arg;
    
    my @params = @{ $self->params };
    
    my @missing = map { !exists $arg->{$_} ? $_ : () } @params;
    
    die sprintf "ExtDirect Method %s.%s requires the following ".
                 "parameters: '%s'; these are missing: '%s'\n",
                 $self->action, $self->name,
                 join(', ', @params), join(', ', @missing)
        if @missing;
    
    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments for a Method with named parameters
#

sub prepare_named_arguments {
    my ($self, %arg) = @_;
    
    my $env   = $arg{env};
    my $input = $arg{input};

    my %actual_arg;
    
    my $strict = $self->strict;
    $strict = 1 unless defined $strict;
    
    if ( $strict ) {
        my @names = @{ $self->params };
    
        @actual_arg{ @names } = @$input{ @names };
    }
    else {
        %actual_arg = %$input;
    }
    
    my $env_arg = $self->env_arg;
    
    $actual_arg{ $env_arg } = $env if defined $env_arg;

    return wantarray ? %actual_arg : { %actual_arg };
}

### PUBLIC INSTANCE METHOD ###
#
# Check the arguments for a Method with ordered parameters
#

sub check_ordered_arguments {
    my ($self, $arg) = @_;
    
    die sprintf "ExtDirect Method %s.%s expects ordered arguments " .
                "in arrayref\n"
        unless 'ARRAY' eq ref $arg;
    
    my $want_len = $self->len;
    my $have_len = @$arg;
    
    die sprintf "ExtDirect Method %s.%s requires %d argument(s) ".
                "but only %d are provided\n",
                $self->action, $self->name, $want_len, $have_len
        unless $have_len >= $want_len;
    
    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments for a Method with ordered parameters
#

sub prepare_ordered_arguments {
    my ($self, %arg) = @_;
    
    my $env   = $arg{env};
    my $input = $arg{input};
    
    my @data       = @$input;
    my @actual_arg = splice @data, 0, $self->len;
    
    my $env_arg = $self->env_arg;
    
    no warnings;
    splice @actual_arg, $env_arg, 0, $env if defined $env_arg;
    
    return wantarray ? @actual_arg : [ @actual_arg ];
}

### PUBLIC INSTANCE METHOD ###
#
# Check the arguments when the Method signature is unknown
#

sub check_default_arguments {
    # No checking means the arguments are not checked.
    # Sincerely, C.O.
    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the arguments when the Method signature is unknown
#

sub prepare_default_arguments {
    my ($self, %arg) = @_;
    
    my @actual_arg = ( $arg{input}, $arg{env} );
    
    return wantarray ? @actual_arg : [ @actual_arg ];
}

### PUBLIC INSTANCE METHOD ###
#
# Read-only getter for backward compatibility
#

sub is_formhandler { shift->formHandler }

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
    strict
    package
    env_arg
    upload_arg
    argument_checker
    argument_preparer
/,
    __PACKAGE__->HOOK_TYPES,
];

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => $accessors,
);

1;
