package RPC::ExtDirect::Request::JsonRpc;

use strict;
use warnings FATAL => 'all';

use base 'RPC::ExtDirect::Request';

### PUBLIC CLASS METHOD (ACCESSOR) ###
#
# Return the config property for Exception class
#

sub EXCEPTION_CLASS { 'exception_class_request_json_rpc' }
    
############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Unpacks arguments into a list and validates them
#

my @std_keys = qw/ jsonrpc id method params /;

sub _unpack_arguments {
    my ($self, $arg) = @_;
    
    my $method = $arg->{method};

    die [ "JSON-RPC method name is required" ]
        unless defined $method && length $method > 0;
    
    # JSON-RPC does not have a concept of Action (Class), so we assume
    # that the last item in dotted notation is the method name, and prefix
    # if any is the Action.
    my $action;
    
    if ( $method =~ /\./ ) {
        my @parts = split /\./, $method;
        
        $method = pop @parts;
        $action = join '.', @parts;
    }
    else {
        $action = '__DEFAULT__';
    }
    
    my $id = $arg->{id};
    
    # JSON-RPC spec does not insist on non-empty string but we're
    # trying to stay sane, are we?
    # https://www.jsonrpc.org/specification#request_object
    die [ 'JSON-RPC request id MUST be a non-empty string or a number!' ]
        if $id eq '' or ref $id;
    
    my $params = $arg->{params};
    my $meta = $arg->{metadata};
    my $type = $arg->{jsonrpc} >= '2.0' ? 'jsonrpc' : undef;
    
    die [ "JSON-RPC version 2.0 and later is required" ]
        unless $type;
    
    my %arg_keys = map { $_ => 1, } keys %$arg;
    delete @arg_keys{ @std_keys };

    # Collect ancillary data that might be passed in the packet
    # and make it available to the Hooks. This might be used e.g.
    # for passing CSRF protection tokens, etc.
    my %aux = map { $_ => $arg->{$_} } keys %arg_keys;
    
    my $aux_ref = %aux ? { %aux } : undef;

    return (
        $action, $method, $id, $params, $type, undef, $meta, $aux_ref,
    );
}

### PRIVATE INSTANCE METHOD ###
#
# Return result hashref
#

sub _get_result_hashref {
    my ($self) = @_;
    
    my $tid = $self->tid;
    
    # JSON-RPC notifications MUST NOT return a response
    # https://www.jsonrpc.org/specification#notification
    return unless defined $tid;
    
    my $method_ref = $self->method_ref;

    my $result_ref = {
        jsonrpc => '2.0',
        id      => $tid,
        result  => $self->{result},
    };

    return $result_ref;
}

1;
