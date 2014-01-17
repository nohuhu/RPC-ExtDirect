package RPC::ExtDirect::Request;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect::Config;
use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect::Util qw/ clean_error_message /;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn on for debugging
#
# DEPRECATED. Use `debug_request` or `debug` Config options instead.
#

our $DEBUG;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
#
# DEPRECATED. Use `exception_class_request` or
# `exception_class` Config options instead.
#

our $EXCEPTION_CLASS;

### PUBLIC CLASS METHOD (ACCESSOR) ###
#
# Return the list of supported hook types
#

sub HOOK_TYPES { qw/ before instead after / }

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of RPC::ExtDirect::Request
#

sub new {
    my ($class, $arguments) = @_;
    
    my $api    = delete $arguments->{api};
    my $config = delete $arguments->{config};

    # Need blessed object to call private methods
    my $self = bless {
        api    => $api,
        config => $config,
    }, $class;

    # Unpack and validate arguments
    my ($action_name, $method_name, $tid, $data, $type, $upload)
        = eval { $self->_unpack_arguments($arguments) };
    
    return $self->_exception({
        action  => $action_name,
        method  => $method_name,
        tid     => $tid,
        message => $@->[0],
    }) if $@;

    # Look up the Method
    my $method_ref = $api->get_method_by_name($action_name, $method_name);
    
    return $self->_exception({
        action  => $action_name,
        method  => $method_name,
        tid     => $tid,
        message => 'ExtDirect action or method not found'
    }) unless $method_ref;

    # Check if arguments passed in $data are of right kind
    my $exception = $self->_check_arguments(
        action_name => $action_name,
        method_name => $method_name,
        method_ref  => $method_ref,
        tid         => $tid,
        data        => $data,
    );
    
    return $exception if defined $exception;
    
    # Bulk assignment for brevity
    @$self{ qw/ tid   type   data   upload   method_ref  run_count/ }
        = (    $tid, $type, $data, $upload, $method_ref, 0 );
    
    # Finally, resolve the hooks; it's easier to do that upfront
    # since it involves API lookup
    for my $hook_type ( $class->HOOK_TYPES ) {
        my $hook = $api->get_hook(
            action => $action_name,
            method => $method_name,
            type   => $hook_type,
        );
        
        $self->$hook_type($hook) if $hook;
    }

    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Runs the request; returns false value if method died on us,
# true otherwise
#

sub run {
    my ($self, $env) = @_;

    # Ensure run() is not called twice
    return $self->_set_error("ExtDirect request can't run more than once per batch")
            if $self->run_count > 0;
    
    # Set the flag
    $self->run_count(1);
    
    my $method_ref = $self->method_ref;

    # Prepare the arguments
    my @arg = $method_ref->prepare_method_arguments(
        env    => $env,
        input  => $self->{data},
        upload => $self->upload,
    );
    
    my %params = (
        api        => $self->api,
        method_ref => $method_ref,
        env        => $env,
        arg        => \@arg,
    );

    my ($run_method, $callee, $result, $exception) = (1);

    # Run "before" hook if we got one
    ($result, $exception, $run_method) = $self->_run_before_hook(%params)
        if $self->before && $self->before->runnable;

    # If there is "instead" hook, call it instead of the method
    ($result, $exception, $callee) = $self->_run_method(%params)
        if $run_method;

    # Finally, run "after" hook if we got one
    $self->_run_after_hook(
        %params,
        result    => $result,
        exception => $exception,
        callee    => $callee
    ) if $self->after && $self->after->runnable;

    # Fail gracefully if method call was unsuccessful
    return $self->_process_exception($env, $exception)
        if $exception;

    # Else stash the results
    $self->{result} = $result;

    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# If method call was successful, returns result hashref.
# If an error occured, returns exception hashref. It will contain
# error-specific message only if we're debugging. This is somewhat weird
# requirement in ExtDirect specification. If the debug config option
# is not set, the exception hashref will contain generic error message.
#

sub result {
    my ($self) = @_;

    return $self->_get_result_hashref();
}

sub data {
    my ($self) = @_;

    return 'HASH'  eq ref $self->{data} ? %{ $self->{data} }
         : 'ARRAY' eq ref $self->{data} ? @{ $self->{data} }
         :                                ()
         ;
}

### PUBLIC INSTANCE METHODS ###
#
# Read-write accessors.
#

my $accessors = [qw/
    config
    api
    method_ref
    type
    tid
    state
    where
    message
    upload
    run_count
/,
    __PACKAGE__->HOOK_TYPES,
];

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => $accessors,
);

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Return new Exception object
#

sub _exception {
    my ($self, $params) = @_;
    
    my $config   = $self->config;
    my $ex_class = $config->exception_class_request;
    
    eval "require $ex_class";
    
    my $where = $params->{where};

    if ( !$where ) {
        my ($package, $sub)
            = (caller 1)[3] =~ / \A (.*) :: (.*?) \z /xms;
        $params->{where} = $package . '->' . $sub;
    };
    
    return $ex_class->new({
        config => $config,
        debug  => $config->debug_request,
        %$params
    });
}

### PRIVATE INSTANCE METHOD ###
#
# Replaces Request object with Exception object
#

sub _set_error {
    my ($self, $msg, $where) = @_;

    # Munge $where to avoid it being '_set_error' all the time
    if ( !defined $where ) {
        my ($package, $sub) = (caller 1)[3] =~ / \A (.*) :: (.*?) \z /xms;
        $where = $package . '->' . $sub;
    };
    
    my $method_ref = $self->method_ref;

    # We need newborn Exception object to tear its guts out
    my $ex = $self->_exception({
        action  => $method_ref->action,
        method  => $method_ref->name,
        tid     => $self->tid,
        message => $msg,
        where   => $where
    });

    # Now the black voodoo magiKC part, live on stage
    delete @$self{ keys %$self };
    @$self{ keys %$ex } = values %$ex;

    # Finally, cover our sins with a blessing and we've been born again!
    bless $self, ref $ex;

    # Humbly return failure to be propagated upwards
    return '';
}

### PRIVATE INSTANCE METHOD ###
#
# Unpacks arguments into a list and validates them
#

sub _unpack_arguments {
    my ($self, $arg) = @_;

    # Unpack and normalize arguments
    my $action = $arg->{extAction} || $arg->{action};
    my $method = $arg->{extMethod} || $arg->{method};
    my $tid    = $arg->{extTID}    || $arg->{tid};
    my $data   = $arg->{data}      || $arg;
    my $type   = $arg->{type}      || 'rpc';
    my $upload = $arg->{extUpload} eq 'true' ? $arg->{_uploads}
               :                               undef
               ;

    # Throwing arrayref so that die() wouldn't add file/line to the string
    die [ "ExtDirect action (class name) required" ]
        unless defined $action && length $action > 0;

    die [ "ExtDirect method name required" ]
        unless defined $method && length $method > 0;

    return ($action, $method, $tid, $data, $type, $upload);
}

### PRIVATE INSTANCE METHOD ###
#
# Checks if method arguments are in order
#

sub _check_arguments {
    my ($self, %params) = @_;
    
    my $action_name = $params{action_name};
    my $method_name = $params{method_name};
    my $method_ref  = $params{method_ref};
    my $tid         = $params{tid};
    my $data        = $params{data};

    my $param_names = $method_ref->params;
    my $len         = $method_ref->len;

    # Event poll handlers return Event objects instead of plain data;
    # there is no sense in calling them directly
    if ( $method_ref->pollHandler ) {
        return $self->_exception({
            action  => $action_name,
            method  => $method_name,
            tid     => $tid,
            message => "ExtDirect pollHandler method ".
                       "$action_name.$method_name should not ".
                       "be called directly"
        });
    }

    # There's not much to check for formHandler methods
    elsif ( $method_ref->formHandler ) {
        if ( 'HASH' ne ref($data) || !exists $data->{extAction} ||
             !exists $data->{extMethod} )
        {
            return $self->_exception({
                action  => $action_name,
                method  => $method_name,
                tid     => $tid,
                message => "ExtDirect formHandler method ".
                           "$action_name.$method_name should only ".
                           "be called with form submits"
            })
        }
    }

    # Check if we have right $data type for method's calling convention
    # If the params list is empty, we skip the check
    elsif ( defined $param_names && @$param_names ) {
        if ( not $self->_check_params($param_names, $data) ) {
            return $self->_exception({
                action  => $action_name,
                method  => $method_name,
                tid     => $tid,
                message => "ExtDirect method $action_name.$method_name ".
                           "needs named parameters: " .
                           join( ', ', @$param_names )
            });
        }
    }

    # Check if we have enough data for the method with numbered arguments
    elsif ( defined $len ) {
        my $real_len = @$data;

        if ( $real_len < $len ) {
            return $self->_exception({
                action  => $action_name,
                method  => $method_name,
                tid     => $tid,
                message => "ExtDirect method $action_name.$method_name ".
                           "needs $len arguments instead of $real_len"
            });
        }
    };

    # undef means no exception
    return undef;               ## no critic
}

### PRIVATE INSTANCE METHOD ###
#
# Checks if data passed to method has all named parameters
# defined for the method
#

sub _check_params {
    my ($self, $param_names, $data) = @_;

    # $data should be a hashref
    return unless ref $data eq 'HASH';

    # Note that we don't check definedness -- a parameter
    # may be optional for all we care
    for my $param ( @$param_names ) {
        return unless exists $data->{ $param };
    };

    # Got 'em all
    return 1;
}

### PRIVATE INSTANCE METHOD ###
#
# Run "before" hook
#

sub _run_before_hook {
    my ($self, %params) = @_;
    
    my ($run_method, $result, $exception) = (1);
    
    # This hook may die() with an Exception
    my $hook_result = eval { $self->before->run( %params ) };

    # If "before" hook died, cancel Method call
    if ( $@ ) {
        $exception  = $@;
        $run_method = !1;
    };

    # If "before" hook returns anything but number 1,
    # treat it as Ext.Direct response and do not call
    # the actual method
    if ( $hook_result ne '1' ) {
        $result     = $hook_result;
        $run_method = !1;
    };
    
    return ($result, $exception, $run_method);
}

### PRIVATE INSTANCE METHOD ###
#
# Runs "instead" hook if it exists, or the mehtod itself
#

sub _run_method {
    my ($self, %params) = @_;
    
    # We call methods by code reference    
    my $code     = $params{method_ref}->code;
    my $hook     = $self->instead;
    my $run_hook = $hook && $hook->runnable;

    my $callee = $run_hook ? $hook->code : $code;
    my $result = $run_hook ? eval { $hook->run(%params)            }
               :             eval { $self->_do_run_method(%params) }
               ;
    
    return ($result, $@, $callee);
}

### PRIVATE INSTANCE METHOD ###
#
# Actually run the method or hook and return result
#

sub _do_run_method {
    my ($self, %params) = @_;
    
    my $env     = $params{env};
    my $arg     = $params{arg};
    my $package = $params{method_ref}->package;
    my $code    = $params{method_ref}->code;
    
    return $code->($package, @$arg);
}

### PRIVATE INSTANCE METHOD ###
#
# Run "after" hook
#

sub _run_after_hook {
    my ($self, %params) = @_;
    
    # Localize so that we don't clobber the $@
    local $@;
    
    # Return value and exceptions are ignored
    eval { $self->after->run(%params) };
}

### PRIVATE INSTANCE METHOD ###
#
# Returns result hashref
#

sub _get_result_hashref {
    my ($self) = @_;
    
    my $method_ref = $self->method_ref;

    my $result_ref = {
        type   => 'rpc',
        tid    => $self->tid,
        action => $method_ref->action,
        method => $method_ref->name,
        result => $self->{result},  # To avoid collisions
    };

    return $result_ref;
}

### PRIVATE INSTANCE METHOD ###
#
# Process exception message returned by die() in method or hooks
#

sub _process_exception {
    my ($self, $env, $exception) = @_;

    # Stringify exception and treat it as error message
    my $msg = clean_error_message("$exception");
    
    # Report actual package and method in case we're debugging
    my $method_ref = $self->method_ref;
    my $where      = $method_ref->package .'->'. $method_ref->name;

    return $self->_set_error($msg, $where);
}

1;
