package RPC::ExtDirect::EventProvider;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect::Config;
use RPC::ExtDirect;
use RPC::ExtDirect::NoEvents;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn this on for debugging.
#
# DEPRECATED. Use `debug_eventprovider` Config option instead.
# See RPC::ExtDirect::Config.
#

our $DEBUG;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Serializer class name so it could be configured
#
# DEPRECATED. Use `serializer_class_eventprovider` or `serializer_class`
# Config options instead.
#

our $SERIALIZER_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Event class name so it could be configured
#
# DEPRECATED. Use `event_class_eventprovider` or `event_class`
# Config options instead.
#

our $EVENT_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Request class name so it could be configured
#
# DEPRECATED. Use `request_class_eventprovider` Config option instead.
#

our $REQUEST_CLASS;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Create a new EventProvider object with default API and Config
#

sub new {
    my ($class, %params) = @_;
    
    $params{config} ||= RPC::ExtDirect::Config->new();
    $params{api}    ||= RPC::ExtDirect->get_api();
    
    return bless { %params }, $class;
}

### PUBLIC CLASS/INSTANCE METHOD ###
#
# Runs all poll handlers in succession, collects the Events returned
# by them and returns serialized representation suitable for passing
# on to client side.
#
# Note that the preferred way to call this method is on the EventProvider
# object instance, but we support the class-based way for backwards
# compatibility.
#
# Be aware that the only supported way to configure the EventProvider
# is to pass a Config object to the constructor and then call poll()
# on the instance.
#

sub poll {
    my ($class, $env) = @_;
    
    my $self = ref($class) ? $class : $class->new();
    
    my @poll_handlers = $self->_get_poll_handlers();

    # Even if we have nothing to poll, we must return a stub Event
    # or client side will throw an unhandled JavaScript exception
    return $self->_no_events unless @poll_handlers;

    # Run all the handlers and collect their outputs
    my @results = $self->_run_handlers($env, \@poll_handlers);

    # No events returned by handlers? We still gotta return something.
    return $self->_no_events unless @results;

    # Polling results are always JSON; no content type needed
    my $serialized = $self->_serialize_results(@results);

    # And if serialization fails we have to return something positive
    return $serialized || $self->_no_events;
}

### PUBLIC INSTANCE METHODS ###
#
# Read-write accessors
#

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => [qw/ api config /],
);

############## PRIVATE METHODS BELOW ##############

### PRIVATE CLASS METHOD ###
#
# Return the list of poll handlers
#

sub _get_poll_handlers {
    my ($self) = @_;

    # Compile the list of poll handler
    my @handlers = $self->api->get_poll_handlers();

    # Compile the list of poll handler references
    my @poll_requests;
    for my $handler ( @handlers ) {
        my $req = $self->_create_request($handler);

        push @poll_requests, $req if $req;
    };
    
    return @poll_requests;
}

### PRIVATE CLASS METHOD ###
#
# Create Request off poll handler
#

sub _create_request {
    my ($self, $handler) = @_;
    
    my $config      = $self->config;
    my $api         = $self->api;
    my $action_name = $handler->action;
    my $method_name = $handler->name;
    
    my $request_class = $config->request_class_eventprovider;
    
    eval "require $request_class";
    
    my $req = $request_class->new({
        config => $config,
        api    => $api,
        action => $action_name,
        method => $method_name,
    });
    
    return $req;
}

### PRIVATE CLASS METHOD ###
#
# Run poll handlers and collect results
#

sub _run_handlers {
    my ($self, $env, $requests) = @_;
    
    # Run the requests
    $_->run($env) for @$requests;

    # Collect responses
    my @results = map { $_->result } @$requests;
    
    return @results;
}

### PRIVATE CLASS METHOD ###
#
# Serialize result
#

sub _serialize_results {
    my ($self, @results) = @_;
    
    # Fortunately, client side does understand more than on event
    # batched as array
    my $final_result = @results > 1 ? [ @results ]
                     :                  $results[0]
                     ;
    
    my $config = $self->config;
    my $api    = $self->api;
    
    my $serializer_class = $config->serializer_class_eventprovider;
    
    eval "require $serializer_class";
    
    my $serializer = $serializer_class->new(
        config => $config,
        api    => $api,
    );

    my $json = eval { $serializer->serialize( 1, $final_result ) };

    return $json;
}

### PRIVATE CLASS METHOD ###
#
# Serializes and returns a NoEvents object.
#

sub _no_events {
    my ($self) = @_;
    
    my $config = $self->config;
    my $api    = $self->api;
    
    my $serializer_class = $config->serializer_class_eventprovider;
    
    eval "require $serializer_class";
    
    my $serializer = $serializer_class->new(
        config => $config,
        api    => $api,
    );

    my $no_events  = RPC::ExtDirect::NoEvents->new();
    my $result     = $no_events->result();
    my $serialized = $serializer->serialize(0, $result);

    return $serialized;
}

1;
