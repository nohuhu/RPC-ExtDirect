package RPC::ExtDirect::API;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect::Config;
use RPC::ExtDirect::Serializer;
use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn this on for debugging
#
# DEPRECATED. Use `debug_api` or `debug` Config options instead.
#

our $DEBUG;

### PUBLIC PACKAGE SUBROUTINE ###
#
# Does not import anything to caller namespace but accepts
# configuration parameters. This method always operates on
# the "default" API object stored in RPC::ExtDirect
#

sub import {
    my ($class, @parameters) = @_;

    # Nothing to do
    return unless @parameters;

    # Only hash-like arguments are supported
    croak 'Odd number of parameters in RPC::ExtDirect::API::import()'
        unless (@parameters % 2) == 0;

    my %param = @parameters;
       %param = map { lc $_ => delete $param{ $_ } } keys %param;

    my $api = RPC::ExtDirect->get_api;
    
    for my $type ( $class->HOOK_TYPES ) {
        my $code = delete $param{ $type };
        
        $api->add_hook( type => $type, code => $code )
            if $code;
    };
    
    my $api_config = $api->config;
    
    for my $option ( keys %param ) {
        my $value = $param{$option};
        
        $api_config->$option($value);
    }
}

### PUBLIC CLASS METHOD (ACCESSOR) ###
#
# Return the hook types supported by the API
#

sub HOOK_TYPES { qw/ before instead after/ }

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Init a new API object
#

sub new {
    my $class = shift;
    
    my %params = @_ == 1 && 'HASH' eq ref($_[0]) ? %{ $_[0] } : @_;
    
    $params{config} ||= RPC::ExtDirect::Config->new();
    
    return bless {
        %params,
        actions => {},
    }, $class;
}

### PUBLIC CLASS METHOD ###
#
# Returns JavaScript chunk for REMOTING_API
#

sub get_remoting_api {
    my ($class, %params) = @_;
    
    my ($self, $config);
    
    # There is an option to pass config externally; mainly for testing
    $config = $params{config};
    
    # Backwards compatibility: if called as a class method,
    # operate on the "global" API object instead, and create
    # a new Config instance as well to take care of possibly-set
    # global variables
    if ( ref $class ) {
        $self     = $class;
        $config ||= $self->config;
    }
    else {
        $self     = RPC::ExtDirect->get_api();
        $config ||= $self->config->clone();
        
        $config->read_global_vars();
        
        # This method used to set Serializer debug flag to whatever
        # API's global DEBUG variable was. This was a somewhat
        # convoluted approach, and we're trying to get away from it.
        # However we got to keep compatibility with previous versions
        # at least for package globals, but only for them - if somebody
        # is using new Config-based approach they should set both API
        # and Serializer debug flags separately in the Config instance.
        $config->debug_serialize(1) if $config->debug_api;
    }
    
    # Get REMOTING_API hashref
    my $remoting_api = $self->_get_remoting_api($config);

    # Get POLLING_API hashref
    my $polling_api  = $self->_get_polling_api($config);

    # Return empty string if we got nothing to declare
    return '' if !$remoting_api && !$polling_api;

    # Shortcuts
    my $remoting_var = $config->remoting_var;
    my $polling_var  = $config->polling_var;
    my $auto_connect = $config->auto_connect;
    my $no_polling   = $config->no_polling;
    my $s_class      = $config->serializer_class_api;
    
    my $serializer = $s_class->new( config => $config );

    # Compile JavaScript for REMOTING_API
    my $js_chunk = "$remoting_var = "
                 . ($serializer->serialize(1, $remoting_api) || '{}')
                 . ";\n";

    # If auto_connect is on, add client side initialization code
    $js_chunk .= "Ext.direct.Manager.addProvider($remoting_var);\n"
        if $auto_connect;

    # POLLING_API is added only when there's something in it
    if ( $polling_api && !$no_polling ) {
        $js_chunk .= "$polling_var = "
                  .  ($serializer->serialize(1, $polling_api) || '{}')
                  .  ";\n";

        # Same initialization code for POLLING_API if auto connect is on
        $js_chunk .= "Ext.direct.Manager.addProvider($polling_var);\n"
            if $auto_connect;
    };

    return $js_chunk;
}

### PUBLIC INSTANCE METHOD ###
#
# Get the list of all defined Actions' names
#

sub actions { keys %{ $_[0]->{actions} } }

### PUBLIC INSTANCE METHOD ###
#
# Add an Action (class), or update if it exists
#

sub add_action {
    my ($self, %params) = @_;
    
    $params{action} = $self->_get_action_name( $params{package} )
        unless defined $params{action};
    
    my $action_name = $params{action};
    
    return $self->{actions}->{$action_name}
        if $params{no_overwrite} && exists $self->{actions}->{$action_name};
    
    my $config  = $self->config;
    my $a_class = $config->api_action_class();
    
    # This is to avoid hard binding on the Action class
    eval "require $a_class";
    
    $self->_init_hooks(\%params);
    
    my $action_obj = $a_class->new(
        config => $config,
        %params,
    );
    
    $self->{actions}->{$action_name} = $action_obj;
    
    return $action_obj;
}

### PUBLIC INSTANCE METHOD ###
#
# Return Action object by its name
#

sub get_action_by_name {
    my ($self, $name) = @_;
    
    return $self->{actions}->{$name};
}

### PUBLIC INSTANCE METHOD ###
#
# Return Action object by package name
#

sub get_action_by_package {
    my ($self, $package) = @_;
    
    my @actions = $self->actions;
    
    for my $name ( @actions ) {
        my $action = $self->get_action_by_name($name);
        
        return $action if $action->package eq $package;
    }
    
    return;
}

### PUBLIC INSTANCE METHOD ###
#
# Add a Method, or update if it exists.
# Also create the Method's Action if it doesn't exist yet
#

sub add_method {
    my ($self, %params) = @_;
    
    my $package = delete $params{package};
    
    # Try to find the Action by the package name
    my $action = $self->get_action_by_package($package);
    
    # If Action is not found, create a new one using the last chunk
    # of the package name
    if ( !$action ) {
        my $action_name = $package;
            $action_name =~ s/ \A .* :: //xms;
            
            $action = $self->add_action(
                action  => $action_name,
                package => $package,
            );
    }
    
    # For historical reasons, we support both param_no and len
    # parameters for ordered methods, and both params and
    # param_names for named methods.
    # However the Method definition needs normalized input.
    $params{len} = delete $params{param_no}
        if exists $params{param_no} and not exists $params{len};
    
    $params{params} = delete $params{param_names}
        if exists $params{param_names} and not exists $params{params};
    
    # Go over the hooks and instantiate them
    $self->_init_hooks(\%params);
    
    $action->add_method(\%params);

    # We use the array to keep track of the order
#     push @POLL_HANDLERS, $qualified_name
#         if $attribute_def->{pollHandler};
}

### PUBLIC INSTANCE METHOD ###
#
# Return the Method object by Action and Method name
#

sub get_method_by_name {
    my ($self, $action_name, $method_name) = @_;
    
    my $action = $self->get_action_by_name($action_name);
    
    return unless $action;
    
    return $action->method($method_name);
}

### PUBLIC INSTANCE METHOD ###
#
# Add a hook instance
#

sub add_hook {
    my ($self, %params) = @_;
    
    my              ($package, $method_name, $type, $code)
        = @params{qw/ package   method        type   code /};
    
    # A bit kludgy but there's no point in duplicating
    my $hook = do {
        my $hook_def = { $type => { type => $type, code => $code } };
        $self->_init_hooks($hook_def);
        $hook_def->{$type}
    };
        
    # For backwards compatibility, we support this indirect way
    # of defining the hooks
    if ( $package && $method_name ) {
        my $action = $self->get_action_by_package($package);
        
        croak "Can't find the Action for package $package"
            unless $action;
        
        my $method = $action->method($method_name);
        
        croak "Can't find Method $method_name"
            unless $method;
        
        $method->$type($hook);
    }
    elsif ( $package ) {
        my $action = $self->get_action_by_package($package);
        
        croak "Can't find the Action for package $package"
            unless $action;
        
        $action->$type($hook);
    }
    else {
        $self->$type($hook);
    }
}

### PUBLIC INSTANCE METHOD ###
#
# Return the hook object by Method name, Action or package, and type
#

sub get_hook {
    my ($self, %params) = @_;
    
    my              ($action_name, $package, $method_name, $type)
        = @params{qw/ action        package   method        type/};
    
    my $action = $action_name ? $self->get_action_by_name($action_name)
               :                $self->get_action_by_package($package)
               ;
    
    croak "Can't find action for Method $method_name"
        unless $action;
    
    my $method = $action->method($method_name);
    
    my $hook = $method->$type || $action->$type || $self->$type;
    
    return $hook;
}

### PUBLIC INSTANCE METHOD ###
#
# Return the list of all installed poll handlers
#

sub get_poll_handlers {
    my ($self) = @_;
    
    my @handlers;
    
    my @actions = $self->actions;
    
    ACTION:
    for my $name ( @actions ) {
        my $action = $self->get_action_by_name($name);
        
        my @methods = $action->polling_methods();
        
        push @handlers, map { $action->method($_) } @methods;
    }
    
    return @handlers;
}

### PUBLIC INSTANCE METHODS ###
#
# Simple accessors
#

my $accessors = [qw/
    config
/,
    __PACKAGE__->HOOK_TYPES,
];

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => $accessors,
);

############## PRIVATE METHODS BELOW ##############

### PRIVATE CLASS METHOD ###
#
# Prepares REMOTING_API hashref
#

sub _get_remoting_api {
    my ($self, $config) = @_;

    my @actions = $self->actions;

    # Compile the list of "actions"
    my %api;
    
    ACTION:
    for my $name ( @actions ) {
        my $action = $self->get_action_by_name($name);
        
        # Get the list of methods for Action
        my @methods = $action->remoting_api;

        next ACTION unless @methods;
        
        $api{ $name } = [ @methods ];
    };

    # Compile hashref
    my $remoting_api = {
        url     => $config->router_path,
        type    => 'remoting',
        actions => { %api },
    };

    # Add namespace if it's defined
    $remoting_api->{namespace} = $config->namespace
        if $config->namespace;

    return $remoting_api;
}

### PRIVATE CLASS METHOD ###
#
# Returns POLLING_API definition hashref
#

sub _get_polling_api {
    my ($self, $config) = @_;
    
    my @actions = $self->actions;
    
    # Check if we have any poll handlers in our definitions
    my $has_poll_handlers;
    ACTION:
    for my $name ( @actions ) {
        my $action = $self->get_action_by_name($name);
        
        $has_poll_handlers = $action->has_pollHandlers;

        last ACTION if $has_poll_handlers;
    };

    # No sense in setting up polling if there ain't no Event providers
    return undef unless $has_poll_handlers;         ## no critic
    
    # Got poll handlers, return definition
    return {
        type => 'polling',
        url  => $config->poll_path,
    };
}

### PRIVATE INSTANCE METHOD ###
#
# Instantiate the hooks in an Action or Method definition hashref
#

sub _init_hooks {
    my ($self, $def) = @_;
    
    my $hook_class = $self->config->api_hook_class();
    
    # This is to avoid hard binding on RPC::ExtDirect::Hook
    eval "require $hook_class";
    
    for my $hook_type ( $self->HOOK_TYPES ) {
        next unless my $hook = $def->{$hook_type};

        $def->{$hook_type} = $hook_class->new(%$hook);
    }
}

### PRIVATE INSTANCE METHOD ###
#
# Make an Action name from a package name (strip namespace)
#

sub _get_action_name {
    my ($self, $action_name) = @_;
    
    $action_name =~ s/^.*:://;
    
    return $action_name;
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::API - Remoting API generator for Ext.Direct

=head1 SYNOPSIS

 use RPC::ExtDirect::API         namespace    => 'myApp',
                                 router_path  => '/router',
                                 poll_path    => '/events',
                                 remoting_var => 'Ext.app.REMOTING_API',
                                 polling_var  => 'Ext.app.POLLING_API',
                                 auto_connect => 0,
                                 no_polling   => 0,
                                 before       => \&global_before_hook,
                                 after        => \&global_after_hook,
                                 ;

=head1 DESCRIPTION

This module provides Ext.Direct API code generation.

In order for Ext.Direct client code to know about what Actions (classes)
and Methods are available on the server side, these should be defined in
a chunk of JavaScript code that gets requested from the client at startup
time. It is usually included in the index.html after main ExtJS code:

  <script type="text/javascript" src="extjs/ext-debug.js"></script>
  <script type="text/javascript" src="/extdirect_api"></script>
  <script type="text/javascript" src="myapp.js"></script>

RPC::ExtDirect::API provides a way to configure Ext.Direct definition
variable(s) to accomodate specific application needs. To do so, pass
configuration options to the module when you 'use' it, like shown above.

The following configuration options are supported:

 namespace      - Declares the namespace your Actions will
                  live in. To call the Methods on client side,
                  you will have to qualify them with namespace:
                  namespace.Action.Method, e.g.: myApp.Foo.Bar
 
 router_path    - URI for Ext.Direct Router calls. For CGI
                  implementation, this should be the name of
                  CGI script that provides API; for more
                  sophisticated environments it is an anchor
                  for specified PATH_INFO.
 
 poll_path      - URI for Ext.Direct Event provider calls.
                  Client side will poll this URI periodically,
                  hence the name.
 
 remoting_var   - By default, Ext.Direct Configuration for
                  remoting (forward) Methods is stored in
                  Ext.app.REMOTING_API variable. If for any
                  reason you would like to change that, do this
                  by setting remoting_var.
                  Note that in production environment you would
                  probably want to use a compiled version of
                  JavaScript application that consist of one
                  big JavaScript file. In this case, it is
                  recommended to include API declaration as the
                  first script in your index.html and change
                  remoting API variable name to something like
                  EXT_DIRECT_API. Default variable name depends
                  on Ext.app namespace being available by the
                  time Ext.Direct API is downloaded, which is
                  often not the case.
 
 polling_var    - By default, Ext.Direct does not provide a
                  standard name for Event providers to be
                  advertised in. For similarity, POLLING_API
                  name is used to declare Event provider so
                  it can be used on client side without
                  having to hardcode any URIs explicitly.
                  POLLING_API configuration will only be
                  advertised to client side if there are any
                  Event provider Methods declared.
                  Note that the same caveat applies here as
                  with remoting_var.
 
 no_polling     - Explicitly declare that no Event providers
                  are supported by server side. This results
                  in POLLING_API configuration being suppressed
                  even if there are any Methods with declared
                  pollHandler ExtDirect attribute.
 
 auto_connect   - Generate the code that adds Remoting and
                  Polling providers on the client side without
                  having to do this manually.

 before         - Global "before" hook.
 
 instead        - Global "instead" hook.
 
 after          - Global "after" hook.
 
 For more information on hooks and their usage, see L<RPC::ExtDirect>.

=head1 SUBROUTINES/METHODS

There are no methods intended for external use in this module.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

