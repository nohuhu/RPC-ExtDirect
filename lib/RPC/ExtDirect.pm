package RPC::ExtDirect;

use 5.006;

# ABSTRACT: Ext.Direct implementation for Sencha ExtJS framework

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Carp;
use Attribute::Handlers;

### PACKAGE VARIABLE ###
#
# Version of this module.
#

our $VERSION = '1.01';

### PACKAGE PRIVATE VARIABLE ###
#
# Holds Action names for corresponding Packages
#

my %ACTION_NAME_FOR = ();

### PACKAGE PRIVATE VARIABLE ###
#
# Contains attribute definitions for methods published via ExtDirect
# interface.
#

my %PARAMETERS_FOR = ();

### PACKAGE PRIVATE VARIABLE ###
#
# Contains poll handler method names in order that they were defined
#

my @POLL_HANDLERS = ();

### PUBLIC ATTRIBUTE DEFINITION ###
#
# Defines ExtDirect attribute subroutine and exports it into UNIVERSAL
# namespace.
#

sub UNIVERSAL::ExtDirect : ATTR(CODE) {
    my ($package, $symbol, $referent, $attr, $data) = @_;

    croak "Attribute is not ExtDirect, what's wrong?"
        unless $attr eq 'ExtDirect';

    croak "ExtDirect attribute must define method parameters"
        if !defined $data || ref $data ne 'ARRAY' || @$data < 0;

    my $symbol_name = *{$symbol}{NAME};

    # These parameters depend on attribute input
    my $param_no    = 0;
    my $param_names = undef;
    my $formHandler = 0;
    my $pollHandler = 0;

    my $param_def   = shift @$data;

    # Digits means number of unnamed arguments
    if ( $param_def =~ / \A (\d+) \z /xms ) {
        $param_no = $1;
    }

    # formHandler means exactly that, a handler for form requests
    elsif ( $param_def =~ / \A formHandler \z /xms ) {
        $formHandler = 1;
    }

    # pollHandlers are a bit tricky but are defined here anyway
    elsif ( $param_def =~ / \A pollHandler \z /xms ) {
        $pollHandler = 1;
    }

    elsif ( $param_def =~ / \A params \z /ixms ) {
        my $arg_names = shift @$data;

        croak "ExtDirect attribute 'params' must be followed by ".
              "arrayref containing at least one parameter name"
            if ref $arg_names ne 'ARRAY' || @$arg_names < 1;

        # Copy the names
        $param_names = [ @{ $arg_names } ];
    }

    my $attribute_ref = {
        package     => $package,
        method      => $symbol_name,
        referent    => $referent,
        param_no    => $param_no,
        param_names => $param_names,
        formHandler => $formHandler,
        pollHandler => $pollHandler,
    };

    RPC::ExtDirect->add_method($attribute_ref);
}

### PUBLIC PACKAGE SUBROUTINE ###
#
# Provides facility to assign package-level (action) properties.
# Despite its name, does not import anything in caller package
#

sub import {
    my ($class, @arguments) = @_;

    # Nothing to do
    return unless @arguments;

    # Only hash-like arguments are supported at this time
    croak "Odd number of arguments in RPC::ExtDirect::import()"
        unless (@arguments % 2) == 0;

    my %argument_for = @arguments;

    # Store Action name as an alias for a package
    if ( exists $argument_for{ Action } ) {
        my ($package, $filename, $line) = caller();
        my $alias = $argument_for{ Action };

        RPC::ExtDirect->add_action($package, $alias);
    };
}

### PUBLIC CLASS METHOD ###
#
# Adds Action name as an alias for a package
#

sub add_action {
    my ($class, $package, $action_for_pkg) = @_;

    $ACTION_NAME_FOR{ $package } = $action_for_pkg;
}

### PUBLIC CLASS METHOD ###
#
# Returns the list of Actions that have ExtDirect methods
#

sub get_action_list {
    my %action = map { / \A (.*) :: /xms; $1 => 1 }
                     keys %PARAMETERS_FOR;
    return sort keys %action;               ## no critic
}

### PUBLIC CLASS METHOD ###
#
# Returns the list of poll handler methods as list of
# arrayrefs: [ $action, $method ]
#

sub get_poll_handlers {
    return map { / \A (.*) :: (.*) /xms; [ $1 => $2 ] } @POLL_HANDLERS;
}

### PUBLIC CLASS METHOD ###
#
# Adds a method to internal storage
#

sub add_method {
    my ($class, $attribute_ref) = @_;

    # Unpack for clarity
    my $package = $attribute_ref->{package};
    my $method  = $attribute_ref->{method };

    # If Action alias is not defined, use last chunk of the package name
    my $action
        = exists $ACTION_NAME_FOR{ $package } ? $ACTION_NAME_FOR{ $package }
        :                                       _strip_name( $package )
        ;

    # Methods are addressed by qualified names
    my $qualified_name = $action .'::'. $method;

    # Make a copy of the hashref
    my $attribute_def = {};
    @$attribute_def{ keys %$attribute_ref } = values %$attribute_ref;

    $PARAMETERS_FOR{ $qualified_name } = $attribute_def;

    # We use the array to keep track of the order
    push @POLL_HANDLERS, $qualified_name
        if $attribute_def->{pollHandler};
}

### PUBLIC CLASS METHOD ###
#
# Returns the list of method names with ExtDirect attribute for $action
#

sub get_method_list {
    my ($class, $action) = @_;

    # Action and method names are keys of %PARAMETERS_FOR
    my @keys = sort keys %PARAMETERS_FOR;
    my @list;
    if ( $action ) {
        @list = grep { / \A $action :: /xms } @keys;
        s/ \A $action :: //msx for @list;
    }
    else {
        @list = @keys;
    };

    return wantarray ? @list : shift @list;
}

### PUBLIC CLASS METHOD ###
#
# Returns parameters for given action and method name
# with ExtDirect attribute.
#
# Returns full attribute hash in list context.
# Croaks if called in scalar context.
#

sub get_method_parameters {
    my ($class, $action, $method) = @_;

    croak "Wrong context" unless wantarray;

    croak "ExtDirect action name is required" unless defined $action;
    croak "ExtDirect method name is required" unless defined $method;

    # Retrieve properties
    my $attribute_ref = $PARAMETERS_FOR{ $action .'::'. $method };

    croak "Can't find ExtDirect properties for method $method"
        unless $attribute_ref;

    return %$attribute_ref;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE PACKAGE SUBROUTINE ###
#
# Strip all but the last :: chunk from package name
#

sub _strip_name {
    my ($name) = @_;

    $name =~ s/ \A .* :: //xms;

    return $name;
}

1;

__END__

=pod

=head1 NAME

Expose Perl code to JavaScript web applications through Ext.Direct remoting

=head1 SYNOPSIS

 package Foo::Bar;
    
 use Carp;
 
 use RPC::ExtDirect Action => 'Fubar';
 
 sub foo : ExtDirect(2) {
    my ($class, $arg1, $arg2) = @_;
  
    # do something, store results in scalar
    my $result = ...;
  
    return $result;
 }
  
 sub bar : ExtDirect(params => [foo, bar]) {
    my ($class, %arg) = @_;
  
    my $foo = $arg{foo};
    my $bar = $arg{bar};
  
    # do something, returning scalar
    my $result = [ ... ];
  
    # or throw an exception if something's not right
    croak "Houston, we've got a problem" if $error;
  
    return $result;
 }
  
 sub baz : ExtDirect(formHandler) {
    my ($class, %arg) = @_;
  
    my @form_fields    =  { grep !/^file_uploads$/ }, keys %arg;
    my @uploaded_files = @{ $arg{file_uploads}     };
  
    # do something with form fields and files
    my $result = { ... };
  
    return $result;
 }

=head1 DESCRIPTION

=head2 Abstract

This module provides easy way to map class methods to ExtDirect RPC interface
used with ExtJS JavaScript framework.

=head2 What is this for?

There are many RPC protocols out there; ExtJS framework provides yet another
one called Ext.Direct. In short, Ext.Direct is a way to call server side code
from client side without having to mess with HTML, forms and stuff like that.
Besides forward asynchronous data stream (client calls server), Ext.Direct
also provides mechanism for backward (server to client) asynchronous event
generation.

For more detailed explanation, see
L<http://www.sencha.com/products/extjs/extdirect/>.

=head2 Terminology

Ext.Direct uses the following terms, followed by their descriptions:
 Configuration  - Description of server side calls exposed to
                  client side. Includes information on Action
                  and Method names, as well as argument
                  number and/or names.
 
 API            - JavaScript code that encodes Configuration.
                  Usually generated on the fly by server side
                  script called by client once upon startup.
 
 Router         - Server side component that receives remoting
                  calls, dispatches requests, collects and
                  returns call results.
 
 Action         - Namespace unit; collection of Methods. The
                  nearest Perl analog is package, other 
                  languages may call it a Class. Since the
                  actual calling code is JavaScript, Action
                  names should conform to JavaScript naming
                  rules (i.e. no ::, use dot instead).
 
 Method         - Subroutine exposed through Ext.Direct API
                  to be called by client side. Method is
                  fully qualified by Action and Method names
                  using dot as delimiter: Action.Method.

 Result         - Any data returned by Method upon successful
                  call completion.
 
 Exception      - An error, or any other unwanted condition
                  on server side. Unlike Results, Exceptions
                  are not considered successful; Ext.Direct
                  provides mechanism for managing Exceptions.
  
 Event          - An asynchronous notification that can be
                  generated by server side and passed to
                  client side, resulting in some reaction.
 
 Event Provider - Server side script that gets polled by
                  client side every N seconds; default N
                  is 3 but it can be changed.

=head2 Using RPC::ExtDirect

In order to export subroutine to ExtDirect interface, use ExtDirect(n)
attribute in sub's declaration. Note that there can be no space between
attribute name and opening parentheses. n is mandatory calling convention
declaration; it may be one of the following options:
    - Number of arguments to be passed as ordered list
    - Names of arguments to be passed as hash
    - formHandler that will receive hash of fields and uploaded files
    - pollHandler does not receive any arguments

Unlike Ext.Direct specification (and reference PHP implementation, too)
RPC::ExtDirect does not impose any calling convention on server side code,
except bare minimum. There are no "before" and "after" handlers, no
object instantiation and no assumptions about the code called. That said,
an RPC::ExtDirect Method should conform to the following conventions:
    - Be a package (Class) method, i.e. be aware that its first
      argument will be package name. Just ignore it if you don't
      want it.
 
    - Ordered (numbered) arguments are passed as list in @_, so
      $_[1] is the first argument. No more than number of arguments
      declared in ExtDirect attribute will be passed to Method; any
      extra will be dropped silently. Less actual arguments than
      declared will result in Exception returned to client side,
      and Method never gets called.
 
    - Named arguments are passed as hash in @_. No arguments other
      than declared will be passed to Method; extra arguments will
      be dropped silently. If not all arguments are present in
      actual call, an Exception will be returned and Method never
      gets called.
 
    - Form handlers are passed their arguments as hash in @_.
      Standard Ext.Direct form fields are removed from argument
      hash; uploaded file(s) will be passed in file_uploads hash
      element. It will only be present when there are uploaded
      files.
 
    - All Methods are called in scalar context. Returning one
      scalar value is OK; returning array- or hashref is OK too.
      Do not return blessed objects; it is almost always not
      obvious how to serialize them into JSON that is expected by
      client side. Just don't do it.
 
    - If an error is encountered while processing request, throw
      an exception with die() or croak(). Do not return some
      obscure value that client side is supposed to know about.
  
    - Poll handler methods are called in list context and do not
      receive any arguments. Return values must be instantiated
      Event object(s), see L<RPC::ExtDirect::EventProvider> for
      more detail.

=head2 Caveats

In order to keep this module as simple as possible, I had to sacrifice the
ability to automatically distinguish inherited class methods. In order to
declare inherited class methods as Ext.Direct exportable you have to override
them in subclass, like that:
    
    package foo;
    use RPC::ExtDirect;
    
    sub foo_sub : ExtDirect(1) {
        my ($class, $arg) = @_;
    
        # do something
        ...
    }
    
    package bar;
    use base 'foo';
    
    sub foo_sub : ExtDirect(1) {
        my ($class, $arg) = @_;
    
        # call inherited method
        return __PACKAGE__->SUPER::foo_sub($arg);
    }
    
    sub bar_sub : ExtDirect(2) {
        my ($class, $arg1, $arg2) = @_;
    
        # do something
        ...
    }

On the other hand if you don't like class-based approach, just don't inherit
your packages from one another. In any case, declare your Methods explicitly
every time and there never will be any doubt about what Method gets called in
any given Action.

=head1 DEPENDENCIES

RPC::ExtDirect is dependent on the following modules:
    Carp
    Attribute::Handlers

=head1 BUGS AND LIMITATIONS

Perl versions below 5.6 are not supported.

There are no known bugs in this module. Please report problems to author,
patches are welcome.

=head1 SEE ALSO

Alternative Ext.Direct Perl implementations:
L<CatalystX::ExtJS::Direct> by Moritz Onken,
L<https://github.com/scottp/extjs-direct-perl> by Scott Penrose.

For Web server gateway implementations, see L<CGI::ExtDirect> and
L<Plack::Middleware::ExtDirect> modules based on RPC::ExtDirect engine.

For configurable Ext.Direct API options, see L<RPC::ExtDirect::API>
module.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2011 by Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.
