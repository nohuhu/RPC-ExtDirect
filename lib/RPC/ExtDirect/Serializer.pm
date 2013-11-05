package RPC::ExtDirect::Serializer;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Carp;
use JSON ();

use RPC::ExtDirect::Request;
use RPC::ExtDirect::Exception;
use RPC::ExtDirect::Util qw/
    clean_error_message get_caller_info parse_global_flags
/;

use RPC::ExtDirect::Util::Accessor qw/
    debug
    debug_serialize
    debug_deserialize
    exception_class
    exception_class_serialize
    exception_class_deserialize
    request_class
    json_options
/;

# These are left as namespace holders for backwards compatibility
use RPC::ExtDirect::Serialize;
use RPC::ExtDirect::Deserialize;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new Serializer
#

sub new {
    my ($class, %params) = @_;
    
    my $self = bless { %params }, $class;
    
    # Deal with the legacy global variables
    $self->_parse_global_variables();

    # Set defaults
    $self->exception_class('RPC::ExtDirect::Exception')
        unless $self->exception_class();
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Serializes the data passed to it in JSON
#

sub serialize {
    my ($self, $mute_exceptions, @data) = @_;

    # Try to serialize each response separately;
    # if one fails it's better to return an exception
    # for one response than fail all of them
    my @serialized = map { $self->_encode_response($_, $mute_exceptions) }
                         @data;

    my $text = @serialized == 1 ? shift @serialized
             :                    '[' . join(',', @serialized) . ']'
             ;

    return $text;
}

### PUBLIC INSTANCE METHOD ###
#
# Turns JSONified POST request(s) into array of instantiated
# RPC::ExtDirect::Request (Exception) objects. Returns arrayref.
#

sub decode_post {
    my ($self, $post_text) = @_;

    # Try to decode data, return Exception upon failure
    my $data = eval { $self->_decode_json($post_text) };

    if ( $@ ) {
        my $error = $self->_clean_msg($@);

        my $msg  = "ExtDirect error decoding POST data: '$error'";
        my $xcpt = $self->_exception({
            direction => 'deserialize',
            message   => $msg,
        });
        
        return [ $xcpt ];
    };

    $data = [ $data ] unless ref $data eq 'ARRAY';

    my @requests = map { $self->_request($_) } @$data;

    return \@requests;
}

### PUBLIC INSTANCE METHOD ###
#
# Instantiates Request based on form submitted to ExtDirect handler
# Returns arrayref with single Request.
#

sub decode_form {
    my ($self, $form_hashref) = @_;

    # Create the Request (or Exception)
    my $request = $self->_request($form_hashref);

    return [ $request ];
}

############## PRIVATE METHODS BELOW ##############

my $GLOBAL_FLAGS = [{
    package => 'RPC::ExtDirect::Serialize',
    var     => 'DEBUG',
    type    => 'scalar',
    field   => 'debug_serialize',
    default => undef,
}, {
    package => 'RPC::ExtDirect::Serialize',
    var     => 'EXCEPTION_CLASS',
    type    => 'scalar',
    field   => 'exception_class_serialize',
    default => undef,
}, {
    package => 'RPC::ExtDirect::Deserialize',
    var     => 'DEBUG',
    type    => 'scalar',
    field   => 'debug_deserialize',
    default => undef,
}, {
    package => 'RPC::ExtDirect::Deserialize',
    var     => 'EXCEPTION_CLASS',
    type    => 'scalar',
    field   => 'exception_class_deserialize',
    default => undef,
}, {
    package => 'RPC::ExtDirect::Deserialize',
    var     => 'REQUEST_CLASS',
    type    => 'scalar',
    field   => 'request_class',
    default => 'RPC::ExtDirect::Request',
}, {
    package => 'RPC::ExtDirect::Deserialize',
    var     => 'JSON_OPTIONS',
    type    => 'hash',
    field   => 'json_options',
    default => undef,
}];

### PRIVATE INSTANCE METHOD ###
#
# Go over the global variables available in previous versions,
# and apply their values, if any, to the instance
#
# This cruft is to be removed in the next major version
#

sub _parse_global_variables {
    my ($self) = @_;
    
    parse_global_flags($GLOBAL_FLAGS, $self);
}

### PRIVATE INSTANCE METHOD ###
#
# Clean error message
#

sub _clean_msg {
    my ($self, $msg) = @_;
    
    return clean_error_message($msg);
}

### PRIVATE INSTANCE METHOD ###
#
# Try encoding one response into JSON
#

sub _encode_response {
    my ($self, $response, $suppress_exceptions) = @_;
    
    my $text = eval { $self->_encode_json($response) };

    if ( $@ and not $suppress_exceptions ) {
        my $msg = $self->_clean_msg($@);

        # It's not a given that response/exception hashrefs
        # will be actual blessed objects, so we have to peek
        # into them instead of using accessors
        my $exception = $self->_exception({
            direction => 'serialize',
            action    => $response->{action},
            method    => $response->{method},
            tid       => $response->{tid},
            where     => __PACKAGE__,
            message   => $msg,
        });
        
        $text = eval { $self->_encode_json( $exception->result() ) };
    };
    
    return $text;
}

### PRIVATE INSTANCE METHOD ###
#
# Actually encode JSON
#

sub _encode_json {
    my ($self, $data) = @_;
    
    my $debug   = $self->debug_serialize;
    $debug      = $self->debug if !defined $debug;
    my $options = $self->json_options || {};
    
    # We force UTF-8 as per Ext.Direct spec
    $options->{utf8}      = 1;
    $options->{canonical} = $debug
        unless defined $options->{canonical};
    
    return JSON::to_json($data, $options);
}

### PRIVATE INSTANCE METHOD ###
#
# Actually decode JSON
#

sub _decode_json {
    my ($self, $text) = @_;
    
    my $options = $self->json_options || {};
    
    return JSON::from_json($text, $options);
}

### PRIVATE INSTANCE METHOD ###
#
# Return a new Request object
#

sub _request {
    my ($self, $params) = @_;
    
    my $request_class = $self->request_class;
    
    return $request_class->new($params);
}

### PRIVATE INSTANCE METHOD ###
#
# Return a new Exception object
#

sub _exception {
    my ($self, $params) = @_;
    
    my $direction    = $params->{direction};
    my $getter_class = "exception_class_$direction";
    my $getter_debug = "debug_$direction";
    
    my $exception_class = $self->$getter_class()
                       || $self->exception_class;
    my $debug           = $self->$getter_debug();
    $debug              = $self->debug if !defined $debug;
    
    $params->{debug} = $debug             unless defined $params->{debug};
    $params->{where} = get_caller_info(2) unless defined $params->{where};
    
    
    return $exception_class->new($params);
}

1;

