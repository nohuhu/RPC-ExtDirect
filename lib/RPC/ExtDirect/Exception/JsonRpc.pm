package RPC::ExtDirect::Exception::JsonRpc;

use strict;
use warnings FATAL => 'all';

use base 'RPC::ExtDirect::Exception';

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Returns exception hashref
#

sub _get_exception_hashref {
    my ($self) = @_;

    my $tid = $self->tid;
    
    # RPC-JSON notifications MUST NOT send a response even if an error occured:
    # https://www.jsonrpc.org/specification#response_object
    
    return undef unless defined $tid;

    my $code = $self->code;
    my $data = $self->data;

    # If debug flag is not set, return generic message. This is for
    # compatibility with Ext.Direct specification.
    my $message = $self->debug or $self->verbose
                ? $self->message
                : 'An error has occured while processing request'
                ;
    
    return {
        jsonrpc => '2.0',
        id      => $tid,
        error   => {
            code => (defined($code) ? $code : -32603),
            message => $message,
            (defined($data) ? (data => $data) : ()),
        },
    };
}

1;
