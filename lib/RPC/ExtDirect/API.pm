package RPC::ExtDirect::API;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect::Config;
use RPC::ExtDirect::Serialize;
use RPC::ExtDirect;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn this on for debugging
#

our $DEBUG = 0;

### PACKAGE PRIVATE VARIABLE ###
#
# Holds configuration parameters for API
#

my %OPTION_FOR = ();

### PUBLIC PACKAGE SUBROUTINE ###
#
# Does not import anything to caller namespace but accepts
# configuration parameters
#

sub import {
    my ($class, @arguments) = @_;

    # Nothing to do
    return unless @arguments;

    # Only hash-like arguments are supported at this time
    croak 'Odd number of arguments in '.
          'RPC::ExtDirect::EventProvider::import()'
        unless (@arguments % 2) == 0;

    my %argument_for = @arguments;

    # Parameter names
    my @parameters = qw(
        namespace       router_path     poll_path
        auto_connect    remoting_var    polling_var
        no_polling
    );

    # Set defaults
    $OPTION_FOR{no_polling} = 0;

    PARAMETER:
    for my $parameter ( @parameters ) {
        # This is not going to be used often so grep is ok
        my ($actual_parameter) = grep { /$parameter/i }
                                      keys %argument_for;

        next PARAMETER unless $actual_parameter;

        $OPTION_FOR{ $parameter } = $argument_for{ $actual_parameter };
    };
}

### PUBLIC CLASS METHOD ###
#
# Returns JavaScript chunk for REMOTING_API
#

sub get_remoting_api {
    my ($class) = @_;

    # Set the debugging flag
    local $RPC::ExtDirect::Serialize::DEBUG = $DEBUG;

    # Get configuration class name
    my $config_class = $class->_get_config_class();

    # Get configurable parameters
    my %param;
    $param{namespace}    =  $OPTION_FOR{namespace}
                         || undef;
    $param{router_path}  =  $OPTION_FOR{router_path}
                         || $config_class->get_router_path();
    $param{poll_path}    =  $OPTION_FOR{poll_path}
                         || $config_class->get_poll_path();
    $param{remoting_var} =  $OPTION_FOR{remoting_var}
                         || $config_class->get_remoting_var();
    $param{polling_var}  =  $OPTION_FOR{polling_var}
                         || $config_class->get_polling_var();
    $param{auto_connect} =  $OPTION_FOR{auto_connect};

    # Get REMOTING_API hashref
    my $remoting_api = $class->_get_remoting_api(\%param);

    # Get POLLING_API hashref
    my $polling_api  = $class->_get_polling_api(\%param);

    # Return empty string if we got nothing to declare
    return '' if !$remoting_api && !$polling_api;

    # Shortcuts
    my $remoting_var = $param{remoting_var};
    my $polling_var  = $param{polling_var};
    my $auto_connect = $param{auto_connect};

    # Compile JavaScript for REMOTING_API
    my $js_chunk = "$remoting_var = "
                 . RPC::ExtDirect::Serialize->serialize($remoting_api)
                 . ";\n";

    # If auto_connect is on, add client side initialization code
    $js_chunk .= "Ext.direct.Manager.addProvider($remoting_var);\n"
        if $auto_connect;

    # POLLING_API is added only when there's something in it
    if ( $polling_api && !$OPTION_FOR{no_polling} ) {
        $js_chunk .= "$polling_var = "
                  .  RPC::ExtDirect::Serialize->serialize($polling_api)
                  .  ";\n";

        # Same initialization code for POLLING_API if auto connect is on
        $js_chunk .= "Ext.direct.Manager.addProvider($polling_var);\n"
            if $auto_connect;
    };

    return $js_chunk;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE CLASS METHOD ###
#
# Returns name of the class used to get configuration defaults
# It should be subclassed from RPC::ExtDirect::Config
#

sub _get_config_class { 'RPC::ExtDirect::Config' }

### PRIVATE CLASS METHOD ###
#
# Prepares REMOTING_API hashref
#

sub _get_remoting_api {
    my ($class, $config) = @_;

    # Map Action names to hash keys
    my %actions = map { $_ => 1 } RPC::ExtDirect->get_action_list();

    # Compile the list of "actions"
    ACTION:
    for my $action ( keys %actions ) {
        # Get the list of methods for Action
        my @methods = RPC::ExtDirect->get_method_list($action);

        next ACTION unless @methods;

        my @definitions;

        # Go over each method
        METHOD:
        for my $method ( @methods ) {
            # Get the definition
            my $def_ref = $class->_define_method($action, $method);

            next METHOD unless $def_ref;

            # Store it if it's good
            push @definitions, $def_ref;
        };

        # No definitions means nothing to export (all poll handlers?)
        if ( !@definitions ) {
            delete $actions{ $action };
            next ACTION;
        };

        # Now convert it to a hashref
        $actions{ $action } = [ @definitions ];
    };

    # Compile hashref
    my $remoting_api = {
        url     => $config->{router_path},
        type    => 'remoting',
        actions => \%actions,
    };

    # Add namespace if it's defined
    $remoting_api->{namespace} = $config->{namespace}
        if $config->{namespace};

    return $remoting_api;
}

### PRIVATE CLASS METHOD ###
#
# Returns Action method definition for REMOTING_API
#

sub _define_method {
    my ($class, $action, $method) = @_;

    # Get the parameters
    my %param = RPC::ExtDirect->get_method_parameters($action, $method);

    # Skip poll handlers
    return undef if $param{pollHandler};        ## no critic

    # Form handlers are defined like this (\1 for JSON::true)
    return { name => $method, len => 0, formHandler => \1 }
        if $param{formHandler};

    # Ordinary method with named arguments
    return { name => $method, params => $param{param_names} }
        if $param{param_names};

    # Ordinary method with numbered arguments
    return { name => $method, len => $param{param_no} + 0 };
}

### PRIVATE CLASS METHOD ###
#
# Returns POLLING_API definition hashref
#

sub _get_polling_api {
    my ($class, $config) = @_;

    # Check if we have any poll handlers in our definitions
    my $has_poll_handlers;
    ACTION:
    for my $action ( RPC::ExtDirect->get_action_list() ) {
        # Don't want to depend on List::Util so grep is OK
        $has_poll_handlers = RPC::ExtDirect->get_poll_handlers();

        last ACTION if $has_poll_handlers;
    };

    # No sense in setting up polling if there ain't no Event providers
    return undef unless $has_poll_handlers;         ## no critic

    # Got poll handlers, return definition
    return {
        type => 'polling',
        url  => $config->{poll_path},
    };
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
                                 ;

=head1 DESCRIPTION

This module provides Ext.Direct API code generation.

In order for Ext.Direct client code to know about what Actions (classes)
and Methods are available on the server side, these should be defined in
a chunk of JavaScript code that gets requested from the client at startup
time. It is usually included in index.html after main ExtJS code:

  <script type="text/javascript" src="extjs/ext-debug.js"></script>
  <script type="text/javascript" src="myapp.js"></script>
  <script type="text/javascript" src="/extdirect_api"></script>

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
 
 polling_var    - By default, Ext.Direct does not provide a
                  standard name for Event providers to be
                  advertised in. For similarity, POLLING_API
                  name is used to declare Event provider so
                  it can be used on client side without
                  having to hardcode any URIs explicitly.
                  POLLING_API configuration will only be
                  advertised to client side if there are any
                  Event provider Methods declared.
 
 no_polling     - Explicitly declare that no Event providers
                  are supported by server side. This results
                  in POLLING_API configuration being suppressed
                  even if there are any Methods with declared
                  pollHandler ExtDirect attribute.
 
 auto_connect   - Generate the code that adds Remoting and
                  Polling providers on the client side without
                  having to do this manually.

=head1 SUBROUTINES/METHODS

There are no methods intended for external use in this module.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.
