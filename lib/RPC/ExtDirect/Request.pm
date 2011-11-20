package RPC::ExtDirect::Request;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect ();          # No imports here
use RPC::ExtDirect::Exception;  # Nothing gets imported there anyway

### PACKAGE GLOBAL VARIABLE ###
#
# Turn on for debugging
#

our $DEBUG = 0;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of RPC::ExtDirect::Request
#

sub new {
    my ($class, $arguments) = @_;

    # Need blessed object to call private methods
    my $self = bless {}, $class;

    # A shortcut
    my $xcpt = 'RPC::ExtDirect::Exception';

    # Unpack and validate arguments
    my ($action, $method, $tid, $data, $type, $upload)
        = eval { $self->_unpack_arguments($arguments) };
    return $xcpt->new({ debug   => $DEBUG,  action => $action,
                        method  => $method, tid    => $tid,
                        message => $@->[0] })
        if $@;

    # Look up method parameters
    my %parameters = eval {
        RPC::ExtDirect->get_method_parameters($action, $method)
    };
    return $xcpt->new({ debug   => $DEBUG,  action => $action,
                        method  => $method, tid    => $tid,
                        message => 'ExtDirect action or method not found' })
        if $@;

    # Check if arguments passed in $data are of right kind
    my $exception = $self->_check_arguments($action, $method, $tid, $data,
                                            \%parameters);
    return $exception if defined $exception;

    # Assign attributes
    my @attrs        = qw(action method package referent param_no
                          param_names formHandler
                          tid arguments type data upload run_count);
    @$self{ @attrs } =  ($action, $method,        $parameters{package},
                         $parameters{referent},   $parameters{param_no},
                         $parameters{param_names},$parameters{formHandler},
                         $tid, $data, $type, $data, $upload, 0);

    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Runs the request; returns false value if method died on us,
# true otherwise
#

sub run {
    my ($self) = @_;

    # A shortcut
    my $xcpt = 'RPC::ExtDirect::Exception';

    # Ensure run() is not called twice
    return
        $self->_set_error("ExtDirect request can't be run more than once")
            if $self->run_count > 0;
    
    # Set the flag
    $self->{run_count} = 1;

    # Prepare the arguments
    my @arg = $self->_prepare_method_arguments();

    # We call methods by code reference
    my $package  = $self->package;
    my $referent = $self->referent;

    # Actual methods are always called in scalar context
    my $result = eval { $referent->($package, @arg) };

    # Fail gracefully if method call was unsuccessful
    if ( $@ ) {
        # Remove that nasty newline from standard die() or croak() msg
        chomp $@;

        # When debugging, try our best to remove that frigging
        # line number and file name from error message.
        # It blows up all string comparisons.
        $@ =~ s/(?<![,]) at .*? line \d+(, <DATA> line \d+)?\.?//
            if $DEBUG;

        # Report actual package and method in case we're debugging
        my $where = $self->package .'->'. $self->method;
        my $msg   = "ExtDirect request failed: '$@'";

        return $self->_set_error($msg, $where);
    };

    # Else stash the results
    $self->{result} = $result;

    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# If method call was successful, returns result hashref.
# If an error occured, returns exception hashref. It will contain
# error-specific message only if $DEBUG is set. This is somewhat weird
# requirement in ExtDirect specification. If $DEBUG is not set, exception
# hashref will contain generic error message.
#

sub result {
    my ($self) = @_;

    return $self->_get_result_hashref();
}

### PUBLIC INSTANCE METHODS ###
#
# Read-only getters.
#

sub action      { $_[0]->{action}      }
sub method      { $_[0]->{method}      }
sub package     { $_[0]->{package}     }
sub referent    { $_[0]->{referent}    }
sub param_no    { $_[0]->{param_no}    }
sub type        { $_[0]->{type}        }
sub tid         { $_[0]->{tid}         }
sub state       { $_[0]->{state}       }
sub where       { $_[0]->{where}       }
sub message     { $_[0]->{message}     }
sub upload      { $_[0]->{upload}      }
sub run_count   { $_[0]->{run_count}   }
sub formHandler { $_[0]->{formHandler} }
sub param_names { @{ $_[0]->{param_names} || [] } }
sub data        { @{ $_[0]->{data}              } }

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Replaces Request object with Exception object
#

sub _set_error {
    my ($self, $msg, $where) = @_;

    # Munge $where to avoid it being '_set_error' all the time
    if ( !defined $where ) {
        my ($package, $sub) = (caller 1)[3] =~ / \A (.*) :: (.*?) \z /xms;
        $where = $package . '->' . $sub;
    };

    # A shortcut
    my $xcpt = 'RPC::ExtDirect::Exception';

    # We need newborn Exception object to tear its guts out
    my $ex = $xcpt->new({ debug   => $DEBUG,        action => $self->action,
                          method  => $self->method, tid    => $self->tid,
                          message => $msg,          where  => $where });

    # Now the black voodoo magiKC part, live on stage
    delete @$self{ keys %$self };
    @$self{ keys %$ex } = values %$ex;

    # Finally, cover our sins with a blessing and we're born again!
    bless $self, 'RPC::ExtDirect::Exception';

    # Humbly return failure to be propagated upwards
    return '';
}

### PRIVATE INSTANCE METHOD ###
#
# Unpacks arguments into a list and validates them
#

sub _unpack_arguments {
    my ($self, $arg) = @_;

    # Check if $arg is valid
    croak [ "ExtDirect input error: invalid input" ]
        if !defined $arg || ref $arg ne 'HASH';

    # Unpack and normalize arguments
    my $action = $arg->{extAction} || $arg->{action};
    my $method = $arg->{extMethod} || $arg->{method};
    my $tid    = $arg->{extTID}    || $arg->{tid};
    my $data   = $arg->{data}      || $arg;
    my $type   = $arg->{type}      || 'rpc';
    my $upload = $arg->{extUpload} eq 'true' ? $arg->{_uploads}
               :                               undef
               ;

    # Check required arguments
    croak [ "ExtDirect action (class name) required" ]
        unless defined $action && length $action > 0;

    croak [ "ExtDirect method name required" ]
        unless defined $method && length $method > 0;

    return ($action, $method, $tid, $data, $type, $upload);
}

### PRIVATE INSTANCE METHOD ###
#
# Checks if method arguments are in order
#

sub _check_arguments {
    my ($self, $action, $method, $tid, $data, $method_def) = @_;

    # A shortcut
    my $xcpt = 'RPC::ExtDirect::Exception';

    # Check if we have right $data type for method's calling convention
    if ( defined $method_def->{param_names} ) {
        my $param_names = $method_def->{param_names};

        return $xcpt->new({ debug   => $DEBUG,  action => $action,
                            method  => $method, tid    => $tid,
                            message => "ExtDirect method $action.$method ".
                                       "needs named parameters: " .
                                       join( ', ', @$param_names ) })
            if !$self->_check_params($param_names, $data);
    };

    # Check if we have enough data for the method with numbered arguments
    if ( $method_def->{param_no} ) {
        my $defined_param_no = $method_def->{param_no};
        my $real_param_no    = @$data;

        return $xcpt->new({ debug   => $DEBUG,  action => $action,
                            method  => $method, tid    => $tid,
                            message => "ExtDirect method $action.$method ".
                           "needs $defined_param_no ".
                           "arguments instead of $real_param_no" })
            if $real_param_no < $defined_param_no;
    };

    # There's not much to check for formHandler methods
    if ( $method_def->{formHandler} ) {
        return $xcpt->new({ debug   => $DEBUG,  action => $action,
                            method  => $method, tid    => $tid,
                            message => "ExtDirect formHandler method ".
                                       "$action.$method should only ".
                                       "be called with form submits" })
            if ref $data ne 'HASH' || !exists $data->{extAction} ||
                                      !exists $data->{extMethod};
    };

    # Event poll handlers return Event objects instead of plain data;
    # there is no sense in calling them directly
    if ( $method_def->{pollHandler} ) {
        return $xcpt->new({ debug   => $DEBUG,  action => $action,
                            method  => $method, tid    => $tid,
                            message => "ExtDirect pollHandler method ".
                                       "$action.$method should not ".
                                       "be called directly" });
    };

    # undef means no exception
    return undef;               ## no critic
}

### PRIVATE INSTANCE METHOD ###
#
# Checks if data passed to method has all named parameters
# defined for the method
#

sub _check_params {
    my ($self, $param_names, $data) = @_;

    # $data should be a hashref
    return unless ref $data eq 'HASH';

    # Note that I don't check definedness -- a parameter
    # may be optional for all I care
    for my $param ( @$param_names ) {
        return unless exists $data->{ $param };
    };

    # Got 'em all
    return 1;
}

### PRIVATE INSTANCE METHOD ###
#
# Prepares method arguments to be passed along to the method
#

sub _prepare_method_arguments {
    my ($self) = @_;

    my @arg;

    # Ensure we're passing the right number of arguments
    if ( $self->param_no ) {
        my @data = $self->data;
        @arg     = splice @data, 0, $self->param_no;
    }

    # Pluck the named arguments and stash them into @arg
    elsif ( $self->param_names ) {
        my @names = $self->param_names;
        my $data  = $self->{data};
        my %tmp;
        @tmp{ @names } = @$data{ @names };
        @arg = %tmp;
    }

    # Deal with form handlers
    elsif ( $self->formHandler ) {
        # Data should be hashref here
        my $data = $self->{data};

        # Ensure there are no runaway ExtDirect generic parameters
        my @runaway_params = qw(action method extAction extMethod
                                extTID extUpload _uploads);
        delete @$data{ @runaway_params };

        # Add uploads if there are any
        $data->{file_uploads} = $self->upload
            if $self->upload;

        @arg = %$data;
    }

    return @arg;
}

### PRIVATE INSTANCE METHOD ###
#
# Returns result hashref
#

sub _get_result_hashref {
    my ($self) = @_;

    my $result_ref = {
        type   => 'rpc',
        tid    => $self->tid,
        action => $self->action,
        method => $self->method,
        result => $self->{result},  # To avoid collisions
    };

    return $result_ref;
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Request - Implements Ext.Direct Request objects

=head1 SYNOPSIS

This module is not intended to be used directly.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
