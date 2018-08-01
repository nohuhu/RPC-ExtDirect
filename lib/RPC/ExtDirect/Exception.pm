package RPC::ExtDirect::Exception;

use strict;
use warnings;

use Carp;

use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect::Util qw/ clean_error_message get_caller_info /;
    
### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of Exception.
#

sub new {
    my ($class, $arg) = @_;

    my $self = bless { %$arg }, $class;

    $self->_set_error($arg->{message}, $arg->{where});

    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# A stub for duck typing. Always returns failure.
#

sub run { '' }

### PUBLIC INSTANCE METHOD ###
#
# Returns exception hashref; named so for duck typing.
#

sub result {
    my ($self) = @_;

    return $self->_get_exception_hashref();
}

### PUBLIC INSTANCE METHODS ###
#
# Simple read-write accessors
#

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => [qw/
        debug action method tid where message verbose
        code data type
    /],
);

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Sets internal error condition and message
#

sub _set_error {
    my ($self, $message, $where) = @_;

    # Store the information
    $self->{where}   = defined $where ? $where : get_caller_info(3);
    $self->{message} = $message;

    # Ensure fall through for caller methods
    return !1;
}

### PRIVATE INSTANCE METHOD ###
#
# Returns exception hashref
#

sub _get_exception_hashref {
    my ($self) = @_;

    my $tid = $self->tid;
    my $code = $self->code;
    
    my ($where, $message, $exception_ref);
    
    if ( ($self->type || '') eq 'jsonrpc' ) {
        # RPC-JSON notifications MUST NOT send a response
        # even if an error occured:
        # https://www.jsonrpc.org/specification#response_object
        # This does not include internal errors.
        return undef
            if not defined $tid
               and not (defined $code and $code < 32600);
    
        my $data = $self->data;
        my $message = $self->message;
        
        $message =~ s/ExtDirect/JSON-RPC/g;
        
        $exception_ref = {
            jsonrpc => '2.0',
            (defined($tid) ? (id => $tid) : ()),
            error => {
                code => (defined($code) ? $code : -32603),
                message => $message,
                (defined($data) ? (data => $data) : ()),
            },
        };
    }
    else {
        # If debug flag is not set, return generic message.
        # This is defined in Ext Direct specification.
        if ( $self->debug || $self->verbose ) {
            $where   = $self->where;
            $message = $self->message;
        }
        else {
            $where   = 'ExtDirect';
            $message = 'An error has occured while processing request';
        };
    
        $exception_ref = {
            type    => 'exception',
            action  => $self->action,
            method  => $self->method,
            tid     => $self->tid,
            where   => $where,
            message => $message,
        };
    }

    return $exception_ref;
}

1;
