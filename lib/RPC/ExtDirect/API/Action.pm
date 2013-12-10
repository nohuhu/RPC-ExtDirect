package RPC::ExtDirect::API::Action;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect::Config;
use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (ACCESSOR) ###
#
# Return the hook types supported by this Action class
#

sub HOOK_TYPES { qw/ before instead after / }

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Create a new Action instance
#

sub new {
    my ($class, %params) = @_;
    
    my $config = delete $params{config};
    
    # For the caller, the 'action' parameter makes sense as the
    # Action's name, but from within the Action itself it's just
    # the name
    my $name    = delete $params{action};
    my $package = delete $params{package};
    my $methods = delete $params{methods} || [];
    
    # These checks are mostly for debugging
    croak "Can't create an Action without a name!"
        unless defined $name;
    
    # We accept :: in Action names so that the API would feel
    # more natural on the Perl side, but convert them to dots
    # anyway to be compatible with JavaScript
    $name =~ s/::/./g;
    
    my $self = bless {
        config  => $config,
        name    => $name,
        package => $package,
        methods => {},
        %params,
    }, $class;
    
    $self->add_method($_) for @$methods;
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Merge method definitions from incoming Action
#

sub merge {
    my ($self, $action) = @_;
    
    # Add the methods, or replace if they exist
    $self->add_method(@_) for $action->methods();
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Return the list of this Action's Methods' names
#

sub methods { keys %{ $_[0]->{methods} } }

### PUBLIC INSTANCE METHOD ###
#
# Return the list of this Action's publishable
# (non-pollHandler) methods
#

sub remoting_methods {
    my ($self) = @_;
    
    my @methods = grep { !$self->method($_)->pollHandler }
                       $self->methods;
    
    return @methods;
}

### PUBLIC INSTANCE METHOD ###
#
# Return the list of this Action's pollHandler methods
#

sub polling_methods {
    my ($self) = @_;
    
    my @methods = grep { $self->method($_)->pollHandler }
                       $self->methods;
    
    return @methods;
}

### PUBLIC INSTANCE METHOD ###
#
# Return the list of API definitions for this Action's
# remoting methods
#

sub remoting_api {
    my ($self) = @_;
    
    my @methods = map { $self->method($_)->get_api_definition }
                      $self->remoting_methods;
    
    return @methods;
}

### PUBLIC INSTANCE METHOD ###
#
# Return true if this Action has any pollHandler methods
#

sub has_pollHandlers {
    my ($self) = @_;
    
    my @methods = $self->polling_methods;
    
    return !!@methods;
}

### PUBLIC INSTANCE METHOD ###
#
# Add a method, or replace it if exists.
# Accepts Method instances, or hashrefs to be fed
# to Method->new()
#

sub add_method {
    my ($self, $method) = @_;
    
    my $config = $self->config;
    
    if ( 'HASH' eq ref $method ) {
        my $m_class = $config->api_method_class();
        
        # This is to avoid hard binding on RPC::ExtDirect::API::Method
        eval "require $m_class";
        
        my $name = delete $method->{method} || delete $method->{name};
        
        $method = $m_class->new({
            config  => $config,
            package => $self->package,
            action  => $self->name,
            name    => $name,
            %$method,
        });
    }
    else {
        $method->config($config);
    }
    
    my $m_name = $method->name;
    
    $self->{methods}->{ $m_name } = $method;
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Returns Client::API::Method object by name
#

sub method {
    my ($self, $name) = @_;

    return $self->{methods}->{$name};
}

my $accessors = [qw/
    config
    name
    package
/,
    __PACKAGE__->HOOK_TYPES,
];

RPC::ExtDirect::Util::Accessor::mk_accessors(
    simple => $accessors,
);

1;
