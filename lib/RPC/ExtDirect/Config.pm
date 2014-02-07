package RPC::ExtDirect::Config;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect::Util qw/ parse_global_flags /;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Create a new Config instance
#

sub new {
    my $class = shift;
    
    my %arg;
    
    if ( @_ == 1 and 'HASH' eq ref $_[0] ) {
        %arg = %{ $_[0] };
    }
    elsif ( @_ % 2 == 0 ) {
        %arg = @_;
    }
    elsif ( @_ != 0 ) {
        croak "Odd number of arguments in RPC::ExtDirect::Config->new()";
    }
    
    my $self = bless { %arg }, $class;
    
    $self->_init();
    
    return $self;
}

### PUBLIC INSTANCE METHOD (CONSTRUCTOR) ###
#
# Create a new Config instance from existing one (clone it)
# We're only doing shallow copying here.
#

sub clone {
    my ($self) = @_;
    
    my $clone = bless {}, ref $self;
    
    @$clone{ keys %$self } = values %$self;
    
    return $clone;
}

### PUBLIC INSTANCE METHOD ###
#
# Re-parse the global vars
#

sub read_global_vars {
    my ($self) = @_;
    
    $self->_parse_global_vars();
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Add specified accessors to the Config instance class
#

sub add_accessors {
    my ($self, %arg) = @_;
    
    RPC::ExtDirect::Util::Accessor->mk_accessors(
        class  => ref $self,
        ignore => 1,
        %arg,
    );
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Set the options in bulk by calling relevant setters
#

sub set_options {
    my $self = shift;
    
    my %options = @_ == 1 && 'HASH' eq ref($_[0]) ? %{ $_[0] } : @_;
    
    while ( my ($option, $value) = each %options ) {
        $self->$option($value);
    }
    
    return $self;
}

############## PRIVATE METHODS BELOW ##############

#
# This humongous hashref holds definitions for all fields,
# accessors, default values and global variables involved
# with config objects.
# It's just easier to keep all this stuff in one place
# and pluck the pieces needed for various purposes.
#
my $DEFINITIONS = [{
    accessor => 'api_action_class',
    default  => 'RPC::ExtDirect::API::Action',
}, {
    accessor => 'api_method_class',
    default  => 'RPC::ExtDirect::API::Method',
}, {
    accessor => 'api_hook_class',
    default  => 'RPC::ExtDirect::API::Hook',
}, {
    accessor => 'debug',
    default  => !1,
}, {
    package  => 'RPC::ExtDirect::API',
    var      => 'DEBUG',
    type     => 'scalar',
    setter   => [qw/ debug_api debug_serialize /],
    fallback => 'debug',
}, {
    package  => 'RPC::ExtDirect::EventProvider',
    var      => 'DEBUG',
    type     => 'scalar',
    setter   => 'debug_eventprovider',
    fallback => 'debug',
}, {
    package  => 'RPC::ExtDirect::Serialize',
    var      => 'DEBUG',
    type     => 'scalar',
    setter   => 'debug_serialize',
    fallback => 'debug',
}, {
    package  => 'RPC::ExtDirect::Deserialize',
    var      => 'DEBUG',
    type     => 'scalar',
    setter   => 'debug_deserialize',
    fallback => 'debug',
}, {
    package  => 'RPC::ExtDirect::Request',
    var      => 'DEBUG',
    type     => 'scalar',
    setter   => 'debug_request',
    fallback => 'debug',
}, {
    package  => 'RPC::ExtDirect::Router',
    var      => 'DEBUG',
    type     => 'scalar',
    setter   => [qw/ debug_serialize debug_deserialize debug_request /],
}, {
    accessor => 'exception_class',
    default  => 'RPC::ExtDirect::Exception',
}, {
    package  => 'RPC::ExtDirect::Serialize',
    var      => 'EXCEPTION_CLASS',
    type     => 'scalar',
    setter   => 'exception_class_serialize',
    fallback => 'exception_class',
}, {
    package  => 'RPC::ExtDirect::Deserialize',
    var      => 'EXCEPTION_CLASS',
    type     => 'scalar',
    setter   => 'exception_class_deserialize',
    fallback => 'exception_class',
}, {
    package  => 'RPC::ExtDirect::Request',
    var      => 'EXCEPTION_CLASS',
    type     => 'scalar',
    setter   => 'exception_class_request',
    fallback => 'exception_class',
}, {
    accessor => 'event_class',
    default  => 'RPC::ExtDirect::Event',
}, {
    package  => 'RPC::ExtDirect::EventProvider',
    var      => 'EVENT_CLASS',
    type     => 'scalar',
    setter   => 'event_class_eventprovider',
    fallback => 'event_class',
}, {
    accessor => 'request_class',
    default  => 'RPC::ExtDirect::Request',
}, {
    package  => 'RPC::ExtDirect::Deserialize',
    var      => 'REQUEST_CLASS',
    type     => 'scalar',
    setter   => 'request_class_deserialize',
    fallback => 'request_class',
}, {
    # This is a special case - can be overridden
    # but doesn't fall back to request_class
    accessor => 'request_class_eventprovider',
    default  => 'RPC::ExtDirect::Request::PollHandler',
}, {
    accessor => 'serializer_class',
    default  => 'RPC::ExtDirect::Serializer',
}, {
    setter   => 'serializer_class_api',
    fallback => 'serializer_class',
}, {
    package  => 'RPC::ExtDirect::Router',
    var      => 'SERIALIZER_CLASS',
    type     => 'scalar',
    setter   => 'serializer_class_router',
    fallback => 'serializer_class',
}, {
    package  => 'RPC::ExtDirect::EventProvider',
    var      => 'SERIALIZER_CLASS',
    type     => 'scalar',
    setter   => 'serializer_class_eventprovider',
    fallback => 'serializer_class',
}, {
    accessor => 'deserializer_class',
    default  => 'RPC::ExtDirect::Serializer',
}, {
    package  => 'RPC::ExtDirect::Router',
    var      => 'DESERIALIZER_CLASS',
    type     => 'scalar',
    setter   => 'deserializer_class_router',
    fallback => 'deserializer_class',
}, {
    accessor => 'json_options',
}, {
    package  => 'RPC::ExtDirect::Deserialize',
    var      => 'JSON_OPTIONS',
    type     => 'hash',
    setter   => 'json_options_deserialize',
    fallback => 'json_options',
}, {
    accessor => 'router_class',
    default  => 'RPC::ExtDirect::Router',
}, {
    accessor => 'eventprovider_class',
    default  => 'RPC::ExtDirect::EventProvider',
}, {
    accessor => 'verbose_exceptions',
    default  => !1,  # In accordance with Ext.Direct spec
}, {
    accessor => 'api_path',
    default  => '/extdirectapi',
}, {
    accessor => 'router_path',
    default  => '/extdirectrouter',
}, {
    accessor => 'poll_path',
    default  => '/extdirectevents',
}, {
    accessor => 'remoting_var',
    default  => 'Ext.app.REMOTING_API',
}, {
    accessor => 'polling_var',
    default  => 'Ext.app.POLLING_API',
}, {
    accessor => 'namespace',
}, {
    accessor => 'create_namespace',
    default  => !1,
}, {
    accessor => 'auto_connect',
    default  => !1,
}, {
    accessor => 'no_polling',
    default  => !1,
}];

my @simple_accessors = map  { $_->{accessor} }
                       grep { $_->{accessor} }
                            @$DEFINITIONS;

my @complex_accessors = grep { $_->{fallback} } @$DEFINITIONS;

# Package globals are handled separately, this is only for
# accessors with default values
my %field_defaults = map  { $_->{accessor} => $_ }
                     grep { defined $_->{default} and !exists $_->{var} }
                          @$DEFINITIONS;

my @package_globals = grep { $_->{var} } @$DEFINITIONS;

### PRIVATE INSTANCE METHOD ###
#
# Parse global package variables
#

sub _parse_global_vars {
    my ($self) = @_;
    
    parse_global_flags(\@package_globals, $self);
}

### PRIVATE INSTANCE METHOD ###
#
# Parse global package variables and apply default values
#

sub _init {
    my ($self) = @_;
    
    $self->_parse_global_vars();
    
    # Apply the defaults
    while ( my ($field, $def) = each %field_defaults ) {
        my $default = $def->{default};
        
        $self->$field($default) unless defined $self->$field();
    }
}

### PRIVATE PACKAGE SUBROUTINE ###
#
# Export a deep copy of the definitions for testing
#

sub _get_definitions {
    return [ map { +{ %$_ } } @$DEFINITIONS ];
}

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple    => \@simple_accessors,
    complex   => \@complex_accessors,
    overwrite => 1,
);

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Config - Default options for ExtDirect API

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 DESCRIPTION

This module should be subclassed by implementations of particular
Web environment gateways to provide reasonable defaults.

=head1 SUBROUTINES/METHODS

No subroutines exported by default. None are expected to be called directly.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

