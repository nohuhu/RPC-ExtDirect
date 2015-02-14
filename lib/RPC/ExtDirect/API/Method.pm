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
    
    my $is_ordered
        = defined $arg{len} && !$pollHandler && !$formHandler;
    
    my $is_named
        = !$pollHandler && !$formHandler && !$is_ordered;
    
    my $processor = $pollHandler ? 'pollHandler'
                  : $formHandler ? 'formHandler'
                  : $is_ordered  ? 'ordered'
                  :                'named'
                  ;
    
    # If the Method is named, and params array is empty, force !strict
    if ( $is_named ) {
        $arg{params} = $arg{params} || []; # Better safe than sorry
        $arg{strict} = !1 unless @{ $arg{params} };
    }

    if ( my $meta = delete $arg{metadata} ) {
        my $metadata = {};

        if ( defined (my $len = $meta->{len}) ) {
            # Metadata is optional so ordered with 0 arguments does not
            # make any sense
            die "Ordered metadata cannot have 0 arguments"
                unless $len > 0;

            $metadata->{len} = $len;
            
            $arg{metadata_checker}  = 'check_ordered_metadata';
            $arg{metadata_preparer} = 'prepare_ordered_metadata';
        }
        else {
            my $params = $meta->{params} || [];

            # Same as with main arguments; force !strict if named metadata
            # has empty params
            my $strict = defined $meta->{strict} ? $meta->{strict}
                       : !@$params               ? !1
                       :                           undef
                       ;

            if ( defined $strict ) {
                $metadata->{strict} = $strict;
            }

            $metadata->{params} = $params;
            $metadata->{arg}
                = defined $meta->{arg} ? $meta->{arg} : 'metadata';
            
            $arg{metadata_checker}  = 'check_named_metadata';
            $arg{metadata_preparer} = 'prepare_named_metadata';
        }

        $arg{metadata} = $metadata;
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
    # but application developers can override this method
    # to make permission and/or other kind of checks
    
    # Poll handlers are not declared in the remoting API
    return if $self->pollHandler;
    
    my $name = $self->name;

    my $def;
    
    # Form handlers are defined like this
    # (\1 means JSON::true and doesn't force us to `use JSON`)
    if ( $self->formHandler ) {
        $def = { name => $name, formHandler => \1 };
    }

    # Ordinary method with positioned arguments
    elsif ( $self->is_ordered ) {
        $def = { name => $name, len => $self->len + 0 }
    }

    # Ordinary method with named arguments
    else {
        my $strict = $self->strict;

        $def = {
            name   => $name,
            params => $self->params || [],
            defined $strict ? (strict => ($strict ? \1 : \0)) : (),
        };
    }

    if ( my $meta = $self->metadata ) {
        $def->{metadata} = {};

        if ( $meta->{len} ) {
            $def->{metadata} = {
                len => $meta->{len},
            };
        }
        else {
            my $strict = $meta->{strict};

            $def->{metadata} = {
                params => $meta->{params},
                defined $strict ? (strict => ($strict ? \1 : \0)) : (),
            };
        }
    }

    return $def;
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
# on the server side, RPC::ExtDirect::Request will call this method
# to prepare the arguments that are to be passed to the actual
# Method code that does things; on the client side,
# RPC::ExtDirect::Client will call this method to prepare
# the arguments that are about to be encoded in JSON and passed
# over to the server side.
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
# Check the metadata that was passed in the Ext.Direct request
# to make sure it conforms to the API declared by this Method.
#
# This method is similar to check_method_arguments and operates
# the same way; it is kept separate for easier overriding
# in subclasses.
#

sub check_method_metadata {
    my $self = shift;
    
    my $checker = $self->metadata_checker;
    
    return $self->$checker(@_);
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the metadata to be passed to the called Method,
# in accordance with Method's specification.
#
# This method works similarly to prepare_method_arguments
# and is kept separate for easier overriding in subclasses.
#

sub prepare_method_metadata {
    my $self = shift;
    
    my $preparer = $self->metadata_preparer;
    
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
    my ($self, $arg, $meta) = @_;
    
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
    
    if ( my $meta_arg = $self->meta_arg ) {
        my $meta = $self->prepare_method_metadata($arg{metadata});
        $data{ $meta_arg } = $meta if defined $meta;
    }

    return wantarray ? %data : { %data };
}

### PUBLIC INSTANCE METHOD ###
#
# Check the arguments for a Method with named parameters.
#
# Note that it does not matter if the Method expects its
# arguments to be strictly conforming to the declaration
# or not; in case of !strict the listed parameters are
# still mandatory. In fact !strict only means that
# non-declared parameters are not dropped.
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
# Check the metadata for Methods that expect it by-name
#

sub check_named_metadata {
    my ($self, $meta) = @_;
    
    die sprintf "ExtDirect Method %s.%s expects metadata key/value" .
                "pairs in hashref\n", $self->action, $self->name
        unless 'HASH' eq ref $meta;
    
    my $meta_def = $self->metadata;
    my @meta_params = @{ $meta_def->{params} };
    
    my @missing = map { !exists $meta->{$_} ? $_ : () } @meta_params;
    
    die sprintf "ExtDirect Method %s.%s requires the following ".
                "metadata keys: '%s'; these are missing: '%s'\n",
                $self->action, $self->name,
                join(', ', @meta_params), join(', ', @missing)
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

    if ( my $meta_arg = $self->meta_arg ) {
        my $meta = $self->prepare_method_metadata($arg{metadata});
        $actual_arg{ $meta_arg } = $meta if defined $meta;
    }

    return wantarray ? %actual_arg : { %actual_arg };
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the metadata for Methods that expect it by-name
#

sub prepare_named_metadata {
    my ($self, %arg) = @_;
    
    my $meta_def   = $self->metadata;
    my $meta_input = $arg{metadata};
    my %meta;
    
    my $strict = $meta_def->{strict};
    $strict = 1 unless defined $strict;
    
    if ( $strict ) {
        my @params = @{ $meta_def->{params} };
        
        @meta{ @params } = @$meta_input{ @params };
    }
    else {
        %meta = %$meta_input;
    }
    
    return \%meta;
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
# Check the metadata for Methods that expect it by-position
#

sub check_ordered_metadata {
    my ($self, $meta) = @_;
    
    die sprintf "ExtDirect Method %s.%s expects metadata in arrayref\n",
                $self->action, $self->name
        unless 'ARRAY' eq ref $meta;
    
    my $meta_def = $self->metadata;
    my $want_len = $meta_def->{len};
    my $have_len = @$meta;
    
    die sprintf "ExtDirect Method %s.%s requires %d metadata ".
                "value(s) but only %d are provided\n",
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
    
    if ( defined (my $meta_arg = $self->meta_arg) ) {
        my $meta = $self->prepare_method_metadata($arg{metadata});
        splice @actual_arg, $meta_arg, 0, $meta if defined $meta;
    }

    return wantarray ? @actual_arg : [ @actual_arg ];
}

### PUBLIC INSTANCE METHOD ###
#
# Prepare the metadata for Methods that expect it by-position
#

sub prepare_ordered_metadata {
    my ($self, %arg) = @_;
    
    my $meta_def   = $self->metadata;
    my $meta_input = $arg{metadata};
    
    my @meta = splice @$meta_input, 0, $meta_def->{len};
    
    return \@meta;
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
    metadata
    formHandler
    pollHandler
    is_ordered
    is_named
    strict
    package
    env_arg
    upload_arg
    meta_arg
    argument_checker
    argument_preparer
    metadata_checker
    metadata_preparer
/,
    __PACKAGE__->HOOK_TYPES,
];

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => $accessors,
);

1;
