package RPC::ExtDirect::Serializer;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Carp;
use JSON ();

use RPC::ExtDirect::Config;

use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect::Util qw/
    clean_error_message get_caller_info parse_global_flags
/;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new Serializer
#

sub new {
    my ($class, %arg) = @_;
    
    my $self = bless { %arg }, $class;
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Serialize the data passed to it in JSON
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
    local $@;
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

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => [qw/ config api /],
);

############## PRIVATE METHODS BELOW ##############

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
    
    local $@;
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
        
        local $@;
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
    
    my $config  = $self->config;
    my $debug   = $config->debug_serialize;
    my $options = $config->json_options || {};
    
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
    
    my $options = $self->config->json_options || {};
    
    return JSON::from_json($text, $options);
}

### PRIVATE INSTANCE METHOD ###
#
# Return a new Request object
#

sub _request {
    my ($self, $arg) = @_;
    
    my $api           = $self->api;
    my $config        = $self->config;
    my $request_class = $config->request_class_deserialize;
    
    eval "require $request_class";
    
    return $request_class->new({        
        config => $config,
        api    => $api,
        %$arg
    });
}

### PRIVATE INSTANCE METHOD ###
#
# Return a new Exception object
#

sub _exception {
    my ($self, $arg) = @_;
    
    my $direction = $arg->{direction};

    my $config    = $self->config;
    my $getter_class = "exception_class_$direction";
    my $getter_debug = "debug_$direction";
    
    my $exception_class    = $config->$getter_class();
    my $debug              = $config->$getter_debug();
    
    eval "require $exception_class";
    
    $arg->{debug} = !!$debug           unless defined $arg->{debug};
    $arg->{where} = get_caller_info(2) unless defined $arg->{where};
    
    $arg->{verbose} = $config->verbose_exceptions();
    
    return $exception_class->new($arg);
}

1;
