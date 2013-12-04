package RPC::ExtDirect;

use 5.006;

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Carp;
use Attribute::Handlers;

# Can't `use` here to avoid circular dependency
require RPC::ExtDirect::API;
use RPC::ExtDirect::Util;

### PACKAGE VARIABLE ###
#
# Version of this module.
#

our $VERSION = '3.00';

### PACKAGE GLOBAL VARIABLE ###
#
# Debugging; defaults to off.
#
# DEPRECATED. Use `debug` Config option instead.
#

our $DEBUG;

#
# This is a bit hacky, but we got to keep a reference to the API object
# so that *compilation time* attributes would work as expected,
# as well as the configuration options for the RPC::ExtDirect::API class.
#
{
    my $api = RPC::ExtDirect::API->new();
    
    sub get_api { $api }
}


### PUBLIC PACKAGE SUBROUTINE ###
#
# Provides facility to assign package-level (action) properties.
# Despite its name, does not import anything in caller package
#

sub import {
    my ($class, @params) = @_;

    # Nothing to do
    return unless @params;

    # Only hash-like arguments are supported
    croak "Odd number of parameters in RPC::ExtDirect::import()"
        unless (@params % 2) == 0;

    my %param = @params;
       %param = map { lc $_ => delete $param{ $_ } } keys %param;

    my ($package, $filename, $line) = caller();
    
    my $api = $class->get_api;

    # Store Action (class) name as an alias for a package
    my $action_name = defined $param{action} ? $param{action}
                    : defined $param{class}  ? $param{class}
                    :                          undef
                    ;
    
    # We don't want to overwrite the existing Action, if any
    $api->add_action(
        package      => $package,
        action       => $action_name,
        no_overwrite => 1,
    );

    # Store package level hooks
    for my $type ( $api->HOOK_TYPES ) {
        my $code = $param{ $type };

        $api->add_hook( package => $package, type => $type, code => $code )
            if defined $code;
    };
}

### PUBLIC ATTRIBUTE DEFINITION ###
#
# Define ExtDirect attribute subroutine and export it into UNIVERSAL
# namespace. Attribute processing phase depends on the perl version
# we're running
#
{
    my $phase = $] >= 5.012 ? 'BEGIN' : 'CHECK';
    my $pkg   = __PACKAGE__;
    
    eval <<END;
    sub UNIVERSAL::ExtDirect : ATTR(CODE,$phase) {
        my \$attr = RPC::ExtDirect::Util::parse_attribute(\@_);
        
        ${pkg}->add_method(\$attr);
    }
END
}

### PUBLIC CLASS METHOD ###
#
# Add a hook to the global API
#

sub add_hook {
    my ($class, %params) = @_;

    my $api = $class->get_api();
    
    $api->add_hook(%params);

    return $params{code};
}

### PUBLIC CLASS METHOD ###
#
# Return hook coderef by package and method, with hierarchical lookup.
#

sub get_hook {
    my ($class, %params) = @_;

    my $api  = $class->get_api();
    my $hook = $api->get_hook(%params);
    
    return $hook ? $hook->code : undef;
}

### PUBLIC CLASS METHOD ###
#
# Adds Action name as an alias for a package
#

sub add_action {
    my ($class, $package, $action_for_pkg) = @_;
    
    my $api = $class->get_api();
    
    $api->add_action(
        package => $package,
        action  => $action_for_pkg,
    );
}

### PUBLIC CLASS METHOD ###
#
# Returns the list of Actions that have ExtDirect methods
#
# DEPRECATED. See RPC::ExtDirect::API for replacement.
#

sub get_action_list {
    my ($class) = @_;
    
    my $api = $class->get_api();
    
    my @actions = sort $api->actions();
    
    return @actions;
}

### PUBLIC CLASS METHOD ###
#
# Returns the list of poll handler methods as list of
# arrayrefs: [ $action, $method ]
#
# DEPRECATED. See RPC::ExtDirect::API for replacement.
#

sub get_poll_handlers {
    my ($class) = @_;
    
    my $api     = $class->get_api();
    my @actions = $class->get_api->actions;
    my @handlers;
    
    for my $name ( @actions ) {
        my $action  = $api->get_action_by_name($name);
        my @methods = $action->polling_methods;
        
        push @handlers, [ $name, $_ ] for @methods;
    }
    
    return @handlers;
}

### PUBLIC CLASS METHOD ###
#
# Adds a method to internal storage
#

sub add_method {
    my ($class, $attribute_ref) = @_;
    
    my $api = $class->get_api;
    
    $api->add_method( %$attribute_ref );
}

### PUBLIC CLASS METHOD ###
#
# Returns the list of method names with ExtDirect attribute
# for $action_name, or all methods for all actions if $action_name
# is empty
#
# DEPRECATED. See RPC::ExtDirect::API for replacement.
#

sub get_method_list {
    my ($class, $action_name) = @_;
    
    my $api = $class->get_api;
    
    my @actions = $action_name ? ( $action_name ) : $api->actions;
    my @list;
    
    for my $name ( @actions ) {
        my $action = $api->get_action_by_name($name);
        
        # The output of this method is inconsistent:
        # when called with $action_name it returns the list of
        # method names; when it is called with empty @_
        # it returns the list of Action::method pairs.
        # Not sure what was the original intent here but we
        # got keep the compatibility. The whole method is
        # deprecated anyway.
        my $tpl = $action_name ? "" : $name.'::';
        
        push @list, map { $tpl.$_ } $action->methods;
    }
    
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
# DEPRECATED. See RPC::ExtDirect::API for replacement.
#

sub get_method_parameters {
    my ($class, $action_name, $method_name) = @_;
    
    croak "Wrong context" unless wantarray;
    
    croak "ExtDirect action name is required" unless defined $action_name;
    croak "ExtDirect method name is required" unless defined $method_name;
    
    my $action = $class->get_api->get_action_by_name($action_name);
    
    croak "Can't find ExtDirect action $action"
        unless $action;
    
    my $method = $action->method($method_name);

    croak "Can't find ExtDirect properties for method $method_name"
        unless $method;
    
    return $method->get_api_definition_compat();
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect - Expose Perl code to Ext JS RIA applications through Ext.Direct remoting

=head1 SYNOPSIS

 package Foo::Bar;
 
 use RPC::ExtDirect Action => 'Fubar',
                    before => \&package_before_hook,
                    after  => \&package_after_hook,
                    ;
  
 sub foo_custom_hook {
    # Check something, return true
    return 1;
 }
 
 sub foo : ExtDirect(2, before => \&foo_custom_hook) {
    my ($class, $arg1, $arg2) = @_;
  
    # do something, store results in scalar
    my $result = ...;
  
    return $result;
 }
  
 # This method doesn't need hooks for some reason
 sub bar
    : ExtDirect(
        params => ['foo', 'bar'], before => 'NONE', after => 'NONE',
      )
 {
    my ($class, %arg) = @_;
  
    my $foo = $arg{foo};
    my $bar = $arg{bar};
  
    # do something, returning scalar
    my $result = eval { ... };
  
    # or throw an exception if something's wrong
    die "Houston, we've got a problem: $@\n" if $@;
  
    return $result;
 }
  
 sub baz : ExtDirect(formHandler) {
    my ($class, %arg) = @_;
  
    my @form_fields    = grep { !/^file_uploads$/  } keys %arg;
    my @uploaded_files = @{ $arg{file_uploads}     };
  
    # do something with form fields and files
    my $result = { ... };
  
    return $result;
 }
  
 sub package_before_hook {
    my ($class, %params) = @_;
  
    # Unpack parameters
    my ($method, $env) = @params{ qw/method _env/ };
  
    # Decide if user is authorized to call this method
    my $authorized = check_authorization($method, $env);
  
    # Positive
    return 1 if $authorized;
  
    # Negative, return error string
    return 'Not authorized';
 }
  
 sub package_after_hook {
    my ($class, %params) = @_;
  
    # Unpack parameters
    my ($method, $result, $ex) = @params{ qw/method result exception/ };
    
    # Log the action
    security_audit_log($method, $result, $ex);
 }

=head1 DESCRIPTION

=head2 Abstract

This module provides an easy way to map Perl code to Ext.Direct RPC
interface used with Ext JS JavaScript framework.

=head2 What Ext.Direct is for?

Ext.Direct is a high level RPC protocol that allows easy and fast
integration of server components with JavaScript interface. Client side
stack is built in Ext JS core and is used by many components like data Stores,
Forms, Grids, Charts, etc. Ext.Direct supports request batching, file uploads,
event polling and many other features.

Besides simplicity and ease of use, Ext.Direct allows to achieve very clean
code and issue separation both on server and client sides, which in turn
results in simplified code, greater overall software quality and shorter
development times.

From Perl module developer perspective, Ext.Direct is just a method
attribute; it doesn't matter if it's called from Perl code or through
Ext.Direct. This approach, in particular, allows for multi-tiered testing:

=over 4 

=item *

Server side methods can be tested without setting up HTTP environment
with the usual tools like Test::More

=item *

Server side classes can be tested as a whole via Ext.Direct calls
using Perl client

=item *

Major application components are tested with browser automation tools
like Selenium.

=back

For more information on Ext.Direct, see
L<http://www.sencha.com/products/extjs/extdirect/>.

=head2 Terminology

Ext.Direct uses the following terms, followed by their descriptions:

=over 4

=item Configuration

Description of server side calls exposed to client side. Includes
information on Action and Method names, as well as argument number
and/or names

=item API

JavaScript chunk that encodes Configuration. Usually generated
by application server and retrieved by client once upon startup.
Another option is to embed API declaration in client side application
code.

=item Router

Server side component that receives remoting calls, dispatches requests,
collects and returns call Results or Exceptions.

=item Action

Namespace unit; collection of Methods. The nearest Perl analog is package,
other languages may call it a Class. Since the actual calling code is
JavaScript, Action names should conform to JavaScript naming rules
(i.e. no '::', use dots instead).

=item Method

Subroutine exposed through Ext.Direct API to be called by client side.
Method is fully qualified by Action and Method names using dot as
delimiter: Action.Method.

=item Result

Any data returned by Method upon successful or unsuccessful call completion.
This includes application logic errors. 'Not authenticated' and alike events
should be returned as Results, not Exceptions.

=item Exception

Fatal error, or any other unrecoverable event in application code. Calls
that produce Exception instead of Result are considered unsuccessful;
Ext.Direct provides built in mechanism for managing Exceptions.

Exceptions are not used to indicate errors in application logic flow,
only for catastrophic conditions. Nearest analog is status code 500
for HTTP responses.

Examples of Exceptions are: request JSON is broken and can't be decoded;
called Method dies because of internall error; Result cannot be encoded
in JSON, etc.

=item Event

An asynchronous notification that can be generated by server side and
passed to client side, resulting in some reaction. Events are useful
for status updates, progress indicators and other predictably occuring
conditions and events.

=item Event Provider

Server side script that gets polled by client side every N seconds;
default N is 3 but it can be changed in client side configuration.

=back

=head1 USING RPC::EXTDIRECT

In order to export subroutine to ExtDirect interface, use C<ExtDirect(n, ...)>
attribute in sub declaration. Note that there can be no space between
attribute name and opening parentheses. In Perls older than 5.12, attribute
declaration can't span multiple lines, i.e. the whole C<ExtDirect(n, ...)>
should fit in one line.

n is mandatory calling convention declaration; it may be one of the following
options:

=over 4

=item *

Number of arguments to be passed as ordered list

=item *

Names of arguments to be passed as hash

=item *

formHandler: method will receive hash of fields and file uploads

=item *

pollHandler: method that provides Events when polled by client

=back

Optional method attributes can be specified after calling convention
declaration, in hash-like C<key =E<gt> value> form. Optional attributes
are:

=over 4

=item *

before: code reference to use as "before" hook. See L</HOOKS>

=item *

instead: code reference to "instead" hook

=item *

after: code reference to "after" hook.

=back

=head1 METHODS

Unlike Ext.Direct specification (and reference PHP implementation, too)
RPC::ExtDirect does not impose strict architectural notation on server
side code. There is no mandatory object instantiation and no assumption
about the code called. That said, an RPC::ExtDirect Method should conform
to the following conventions:

=over 4

=item *

Be a class method, i.e. be aware that its first argument will be package name.
Just ignore it if you don't want it.

=item *

Ordered (numbered) arguments are passed as list in @_, so $_[1] is the first
argument. No more than number of arguments declared in ExtDirect attribute
will be passed to Method; any extra will be dropped silently. Less actual
arguments than declared will result in Exception returned to client side,
and Method never gets called.

The last argument is an environment object (see L<ENVIRONMENT OBJECTS>).
For methods that take 0 arguments, it will be the first argument after
class name.

=item *

Named arguments are passed as hash in @_. No arguments other than declared
will be passed to Method; extra arguments will be dropped silently. If not
all arguments are present in actual call, an Exception will be returned and
Method never gets called.

Environment object will be passed in '_env' key.

=item *

Form handlers are passed their arguments as hash in @_. Standard Ext.Direct
form fields are removed from argument hash; uploaded file(s) will be passed
in file_uploads hash element. It will only be present when there are uploaded
files. For more info, see L</UPLOADS>.

Environment object will be passed in '_env' key.

=item *

All remoting Methods are called in scalar context. Returning one scalar value
is OK; returning array- or hashref is OK too.

Do not return blessed objects; it is almost always not obvious how to
serialize them into JSON that is expected by
client side; JSON encoder will choke and an Exception will
be returned to the client.

=item *

If an error is encountered while processing request, throw
an exception: die "My error string\n". Note that "\n" at
the end of error string; if you don't add it, die() will
append file name and line number to the error message;
which is probably not the best idea for errors that are not
shown in console but rather passed on to JavaScript client.

RPC::ExtDirect will trim that last "\n" for you before
sending Exception back to client side.

=item *

Poll handler methods are called in list context and do not
receive any arguments except environment object. Return values
must be instantiated Event object(s), see L<RPC::ExtDirect::Event>
for more detail.

=back

=head1 HOOKS

Hooks provide an option to intercept method calls and modify arguments
passed to the methods, or cancel their execution. Hooks are intended
to be used as a shim between task-oriented Methods and Web specifics.

Methods should not, to the reasonable extent, be aware of their
environment or care about it; Hooks are expected to know how to deal with
Web intricacies but not be task oriented.

The best uses for Hooks are: application or package-wide pre-call setup,
user authorization, logging, cleanup, testing, etc.

A hook is a Perl subroutine (can be anonymous, too). Hooks can be of three
types:

=over 4

=item *

"Before" hook is called before the Method, and can be used
to change Method arguments or cancel Method execution. This
hook must return numeric value 1 to allow Method call. Any
other value will be interpreted as Ext.Direct Result; it
will be returned to client side and Method never gets called.

Note that RPC::ExtDirect will not make any assumptions about
this hook's return value; returning a false value like '' or 0
will probably look not too helpful from client side code.

If this hook throws an exception, it is returned as Ext.Direct
Exception to the client side, and the Method does not execute.

=item *

"Instead" hook replaces the Method it is assigned to. It is
the hook sub's responsibility to call (or not call) the Method
and return appropriate Result.

If this hook throws an exception, it is interpreted as if the
Method trew it.

=item *

"After" hook is called after the Method or "instead" hook. This
hook cannot affect Method execution, it is intended mostly for
logging and testing purposes; its input include Method's
Result or Exception.

This hook's return value and thrown exceptions are ignored.

=back

Hooks can be defined on three levels, in order of precedence: method,
package and global. For each Method, only one hook of each type can be
applied. Hooks specified in Method definition take precedence over all
other; if no method hook is found then package hook applies; and if
there is no package hook then global hook gets called, if any. To avoid
using hooks for a particular method, use 'NONE' instead of coderef;
this way you can specify global and/or package hooks and exclude some
specific Methods piecemeal.

Hooks are subject to the following calling conventions:

=over 4

=item *

Hook subroutine is called as class method, i.e. first argument
is name of the package in which this sub was defined. Ignore it
if you don't need it.

=item *

Hooks receive a hash of the following arguments:

=over 8

=item action

Ext.Direct Action name for the Method

=item method

Ext.Direct Method name

=item package

Name of the package (not Action) where the Method is declared

=item code

Coderef to the Method subroutine

=item param_no
 
Number of parameters when Method accepts ordered arguments

=item param_names

Arrayref with names of parameters when Method accepts named arguments

=item formHandler

True if Method handles form submits

=item pollHandler

True if Method handles Event poll requests

=item arg

Arrayref with actual arguments when Method
accepts ordered args, single Environment
object for poll handlers, hashref otherwise.

Note that this is a direct link to Method's @_
so it is possible to modify the arguments
in "before" hook

=item env

Environment object, see below. Like arg,
this is direct reference to the same object
that will be passed to Method, so it's
possible to modify it in "before" hook

=item before

Coderef to "before" hook for that Method, or undef

=item instead

Coderef to "instead" hook for that Method, or undef

=item after

Coderef to "after" hook for that Method, or undef

=item result

For "after" hooks, the Result returned by
Method or "instead" hook, if any. Does not
exist for "before" and "instead" hooks

=item exception

For "after" hooks, an exception ($@) thrown
by Method or "instead" hook, if any. Does
not exist for "before" and "instead" hooks

=item method_called

For "after" hooks, the reference to actual
code called as Method, if any. Can be either
Method itself, "instead" hook or undef if
the call was canceled.

=item orig

A closure that binds Method coderef to
its current arguments, allowing to call it
as easily as $params{orig}->()

=back

=back

=head1 ENVIRONMENT OBJECTS

Since Hooks, and sometimes Methods too, need to be aware of their Web
environment, it is necessary to give them access to it in some way
without locking on platform specifics. The answer for this problem is
environment objects.

An environment object provides platform-agnostic interface for accessing
HTTP headers, cookies, form fields, etc, by duck typing. Such object is
guaranteed to have the same set of methods that behave the same way
across all platforms supported by RPC::ExtDirect, avoiding portability
issues.

The interface is modeled after de facto standard CGI.pm:

=over 4

=item *

C<$value = $env-E<gt>param('name')> will retrieve parameter by name

=item *

C<@list = $env-E<gt>param()> will get the list of available parameters

=item *

C<$cookie = $env-E<gt>cookie('name')> will retrieve a cookie

=item *

C<@cookies = $env-E<gt>cookie()> will return the list of cookies

=item *

C<$header = $env-E<gt>http('name')> will return HTTP header

=item *

C<@headers = $env-E<gt>http()> will return the list of HTTP headers

=back

Of course it is possible to use environment object in a more sophisticated
way if you like to, however do not rely on it having a well-known class
name as it is not guaranteed.

=head1 FILE UPLOADS

Ext.Direct offers native support for file uploading by using temporary
forms. RPC::ExtDirect supports this feature; upload requests can be
processed in a formHandler Method. The interface aims to be platform
agnostic and will try to do its best to provide the same results in all
HTTP environments supported by RPC::ExtDirect.

In a formHandler Method, arguments are passed as a hash. If one or more
file uploads were associated with request, the argument hash will contain
'file_uploads' key with value set to arrayref of file hashrefs. Each file
hashref will have the following keys:

=over 4

=item type

MIME type of the file

=item size

file size, in octets

=item path

path to temporary file that holds uploaded content

=item handle

opened IO::Handle for temporary file

=item basename

name portion of original file name

=item filename

full original path as sent by client

=back

All files passed to a Method need to be processed in that Method; existence
of temporary files is not guaranteed after Method returns.

=head1 CAVEATS

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

RPC::ExtDirect is dependent on the following modules: L<Attribute::Handlers>,
L<"JSON">.

=head1 BUGS AND LIMITATIONS

In version 2.0, ExtDirect attribute was moved to BEGIN phase instead of
default CHECK phase. While this improves compatibility with
Apache/mod_perl environments, this also causes backwards compatibility
problems with Perl older than 5.12. Please let me know if you need to
run RPC::ExtDirect 2.0 with older Perls; meanwhile RPC::ExtDirect 1.x
will provide compatibility with Perl 5.6.0 and newer.

There are no known bugs in this module. Please report problems to author,
patches are welcome.

=head1 SEE ALSO

Alternative Ext.Direct implementations for Perl:
L<CatalystX::ExtJS::Direct> by Moritz Onken,
L<http://github.com/scottp/extjs-direct-perl> by Scott Penrose,
L<Dancer::Plugin::ExtDirect> by Alessandro Ranellucci.

For Web server gateway implementations, see L<CGI::ExtDirect> and
L<Plack::Middleware::ExtDirect> modules based on RPC::ExtDirect engine.

For configurable Ext.Direct API options, see L<RPC::ExtDirect::API>
module.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 ACKNOWLEDGEMENTS

I would like to thank IntelliSurvey, Inc for sponsoring my work
on version 2.0 of RPC::ExtDirect suite of modules.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2011-2012 by Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<"perlartistic">.

=cut

