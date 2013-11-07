package RPC::ExtDirect::Request;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect ();          # No imports here
use RPC::ExtDirect::Exception;  # Nothing gets imported there anyway
use RPC::ExtDirect::Hook;
use RPC::ExtDirect::Util qw/ clean_error_message /;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn on for debugging
#

our $DEBUG = 0;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
#

our $EXCEPTION_CLASS = 'RPC::ExtDirect::Exception';

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of RPC::ExtDirect::Request
#

sub new {
    my ($class, $arguments) = @_;

    # Need blessed object to call private methods
    my $self = bless {}, $class;

    # Unpack and validate arguments
    my ($action, $method, $tid, $data, $type, $upload)
        = eval { $self->_unpack_arguments($arguments) };
    
    return $self->_exception({
        debug   => $DEBUG,
        action  => $action,
        method  => $method,
        tid     => $tid,
        message => $@->[0]
    }) if $@;

    # Look up method parameters
    my %parameters = eval {
        $self->_get_method_parameters(
            action => $action,
            method => $method
        )
    };
    
    return $self->_exception({
        debug   => $DEBUG,
        action  => $action,
        method  => $method,
        tid     => $tid,
        message => 'ExtDirect action or method not found'
    }) if $@;

    # Check if arguments passed in $data are of right kind
    my $exception = $self->_check_arguments(
        action     => $action,
        method     => $method,
        tid        => $tid,
        data       => $data,
        parameters =>\%parameters
    );
    
    return $exception if defined $exception;

    # Assign attributes
    my @attrs        = qw(action method package referent param_no
                          param_names formHandler pollHandler
                          tid arguments type data upload run_count);
    @$self{ @attrs } =  ($action, $method,         $parameters{package},
                         $parameters{referent},    $parameters{param_no},
                         $parameters{param_names}, $parameters{formHandler},
                         $parameters{pollHandler},
                         $tid, $data, $type, $data, $upload, 0);

    # Hooks should be already defined by now
    $self->_init_hooks(%parameters);

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
    $self->{run_count} = 1;

    # Prepare the arguments
    my @arg = $self->_prepare_method_arguments($env);

    my ($run_method, $callee, $result, $exception) = (1);

    # Run "before" hook if we got one
    ($result, $exception, $run_method)
        = $self->_run_before_hook(env => $env, arg => \@arg)
            if $self->before;

    # If there is "instead" hook, call it instead of the method
    ($result, $exception, $callee) = $self->_run_method(env => $env, arg => \@arg)
            if $run_method;

    # Finally, run "after" hook if we got one
    $self->_run_after_hook(
        env       => $env,
        arg       => \@arg,
        result    => $result,
        exception => $exception,
        callee    => $callee
    ) if $self->after;

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
# error-specific message only if $DEBUG is set. This is somewhat weird
# requirement in ExtDirect specification. If $DEBUG is not set, exception
# hashref will contain generic error message.
#

sub result {
    my ($self) = @_;

    return $self->_get_result_hashref();
}

### PUBLIC INSTANCE METHODS ###
#
# Read-only getters.
#

sub action      { $_[0]->{action}      }
sub method      { $_[0]->{method}      }
sub package     { $_[0]->{package}     }
sub referent    { $_[0]->{referent}    }
sub param_no    { $_[0]->{param_no}    }
sub type        { $_[0]->{type}        }
sub tid         { $_[0]->{tid}         }
sub state       { $_[0]->{state}       }
sub where       { $_[0]->{where}       }
sub message     { $_[0]->{message}     }
sub upload      { $_[0]->{upload}      }
sub run_count   { $_[0]->{run_count}   }
sub formHandler { $_[0]->{formHandler} }
sub pollHandler { $_[0]->{pollHandler} }
sub before      { $_[0]->{before}      }
sub instead     { $_[0]->{instead}     }
sub after       { $_[0]->{after}       }
sub param_names { @{ $_[0]->{param_names} || [] } }

sub data {
    my ($self) = @_;

    return 'HASH'  eq ref $self->{data} ? %{ $self->{data} }
         : 'ARRAY' eq ref $self->{data} ? @{ $self->{data} }
         :                                ()
         ;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Return new Exception object
#

sub _exception {
    my ($self, $params) = @_;
    
    my $where = $params->{where};

    if ( !$where ) {
        my ($package, $sub)
            = (caller 1)[3] =~ / \A (.*) :: (.*?) \z /xms;
        $params->{where} = $package . '->' . $sub;
    };
    
    return $EXCEPTION_CLASS->new($params);
}

### PRIVATE INSTANCE METHOD ###
#
# Return parameters for method being called.
#

sub _get_method_parameters {
    my ($self, %params) = @_;
    
    my $action = $params{action};
    my $method = $params{method};
    
    return RPC::ExtDirect->get_method_parameters($action, $method);
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

    # We need newborn Exception object to tear its guts out
    my $ex = $self->_exception({
        debug   => $DEBUG,
        action  => $self->action,
        method  => $self->method,
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

    # Check if $arg is valid
    croak [ "ExtDirect input error: invalid input" ]
        if !defined $arg || ref $arg ne 'HASH';

    # Unpack and normalize arguments
    my $action = $arg->{extAction} || $arg->{action};
    my $method = $arg->{extMethod} || $arg->{method};
    my $tid    = $arg->{extTID}    || $arg->{tid};
    my $data   = $arg->{data}      || $arg;
    my $type   = $arg->{type}      || 'rpc';
    my $upload = $arg->{extUpload} eq 'true' ? $arg->{_uploads}
               :                               undef
               ;

    # Check required arguments
    croak [ "ExtDirect action (class name) required" ]
        unless defined $action && length $action > 0;

    croak [ "ExtDirect method name required" ]
        unless defined $method && length $method > 0;

    return ($action, $method, $tid, $data, $type, $upload);
}

### PRIVATE INSTANCE METHOD ###
#
# Checks if method arguments are in order
#

sub _check_arguments {
    my ($self, %params) = @_;
    
    my $action     = $params{action};
    my $method     = $params{method};
    my $tid        = $params{tid};
    my $data       = $params{data};
    my $method_def = $params{parameters};

    # Check if we have right $data type for method's calling convention
    if ( defined $method_def->{param_names} ) {
        my $param_names = $method_def->{param_names};

        if ( not $self->_check_params($param_names, $data) ) {
            return $self->_exception({
                debug   => $DEBUG,
                action  => $action,
                method  => $method,
                tid     => $tid,
                message => "ExtDirect method $action.$method ".
                           "needs named parameters: " .
                           join( ', ', @$param_names )
            });
        }
    };

    # Check if we have enough data for the method with numbered arguments
    if ( $method_def->{param_no} ) {
        my $defined_param_no = $method_def->{param_no};
        my $real_param_no    = @$data;

        if ( $real_param_no < $defined_param_no ) {
            return $self->_exception({
                debug   => $DEBUG,
                action  => $action,
                method  => $method,
                tid     => $tid,
                message => "ExtDirect method $action.$method ".
                           "needs $defined_param_no ".
                           "arguments instead of $real_param_no"
            });
        }
    };

    # There's not much to check for formHandler methods
    if ( $method_def->{formHandler} ) {
        if ( ref $data ne 'HASH' || !exists $data->{extAction} ||
             !exists $data->{extMethod} )
        {
            return $self->_exception({
                debug   => $DEBUG,
                action  => $action,
                method  => $method,
                tid     => $tid,
                message => "ExtDirect formHandler method ".
                           "$action.$method should only ".
                           "be called with form submits"
            })
        }
    };

    # Event poll handlers return Event objects instead of plain data;
    # there is no sense in calling them directly
    if ( $method_def->{pollHandler} ) {
        return $self->_exception({
            debug   => $DEBUG,
            action  => $action,
            method  => $method,
            tid     => $tid,
            message => "ExtDirect pollHandler method ".
                       "$action.$method should not ".
                       "be called directly"
        });
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
# Prepares method arguments to be passed along to the method
#

sub _prepare_method_arguments {
    my ($self, $env) = @_;

    my @arg;

    # Deal with form handlers first
    if ( $self->formHandler ) {
        # Data should be hashref here
        my $data = $self->{data};

        # Ensure there are no runaway ExtDirect generic parameters
        my @runaway_params = qw(action method extAction extMethod
                                extTID extUpload _uploads);
        delete @$data{ @runaway_params };

        # Add uploads if there are any
        $data->{file_uploads} = $self->upload
            if $self->upload;

        $data->{_env} = $env;

        @arg = %$data;
    }

    # Pluck the named arguments and stash them into @arg
    elsif ( $self->param_names ) {
        my @names = $self->param_names;
        my $data  = $self->{data};
        my %tmp;
        @tmp{ @names } = @$data{ @names };
        $tmp{_env} = $env;

        @arg = %tmp;
    }

    # Ensure we're passing the right number of arguments
    elsif ( defined $self->param_no ) {
        my @data = $self->data;
        @arg     = splice @data, 0, $self->param_no;

        push @arg, $env;
    };

    return @arg;
}

### PRIVATE INSTANCE METHOD ###
#
# Init Request hooks
#

sub _init_hooks {
    my ($self, %params) = @_;
    
    my @hook_types = qw/ before instead after /;
    @$self{ @hook_types }
        = map { RPC::ExtDirect::Hook->new($_, \%params) } @hook_types;
    
    return $self;
}

### PRIVATE INSTANCE METHOD ###
#
# Run "before" hook
#

sub _run_before_hook {
    my ($self, %params) = @_;
    
    my $env = $params{env};
    my $arg = $params{arg};
    
    my ($run_method, $result, $exception) = (1);
    
    # This hook may die() with an Exception
    my $hook_result = eval { $self->before->run($env, $arg) };

    # If "before" hook died, cancel Method call
    if ( $@ ) {
        $exception  = $@;
        $run_method = '';
    };

    # If "before" hook returns anything but number 1,
    # treat it as Ext.Direct response and do not call
    # the actual method
    if ( $hook_result ne '1' ) {
        $result     = $hook_result;
        $run_method = '';
    };
    
    return ($result, $exception, $run_method);
}

### PRIVATE INSTANCE METHOD ###
#
# Runs "instead" hook if it exists, or the mehtod itself
#

sub _run_method {
    my ($self, %params) = @_;
    
    my $env = $params{env};
    my $arg = $params{arg};
    
    # We call methods by code reference
    my $package  = $self->package;
    my $referent = $self->referent;

    my $callee = $self->instead ? $self->instead->instead
               :                  $referent
               ;

    my $result = $self->instead ? eval { $self->instead->run($env, $arg)   }
               :                  eval { $self->_do_run_method($env, $arg) }
               ;
    
    return ($result, $@, $callee);
}

### PRIVATE INSTANCE METHOD ###
#
# Actually run the method or hook and return result
#

sub _do_run_method {
    my ($self, $env, $arg) = @_;
    
    my $package  = $self->package;
    my $referent = $self->referent;
    
    return $referent->($package, @$arg);
}

### PRIVATE INSTANCE METHOD ###
#
# Run "after" hook
#

sub _run_after_hook {
    my ($self, %params) = @_;
    
    my $env       = $params{env};
    my $arg       = $params{arg};
    my $result    = $params{result};
    my $exception = $params{exception};
    my $callee    = $params{callee};

    # Return value and exceptions are ignored
    eval {
        $self->after->run($env, $arg, $result, $exception, $callee)
    };
    $@ = '';
}

### PRIVATE INSTANCE METHOD ###
#
# Returns result hashref
#

sub _get_result_hashref {
    my ($self) = @_;

    my $result_ref = {
        type   => 'rpc',
        tid    => $self->tid,
        action => $self->action,
        method => $self->method,
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
    my $where = $self->package .'->'. $self->method;

    return $self->_set_error($msg, $where);
}

1;
