package RPC::ExtDirect::Event;

use strict;
use warnings;
no  warnings 'uninitialized';           ## no critic

use Carp;

use RPC::ExtDirect::Util::Accessor;

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Initializes new instance of Event.
#

sub new {
    my $class = shift;
    
    # Allow passing either ordered parameters, or hashref,
    # or even a hash. This is to allow Mooseish and other
    # popular invocation patterns without having to pile on
    # argument converters
    my ($name, $data);
    
    if ( @_ == 1 ) {
        if ( 'HASH' eq ref $_[0] ) {
            $name = $_[0]->{name};
            $data = $_[0]->{data};
        }
        else {
            $name = $_[0];
        }
    }
    elsif ( @_ == 2 ) {
        $name = $_[0];
        $data = $_[1];
    }
    elsif ( @_ % 2 == 0 ) {
        my %params = @_;
        
        $name = $params{name};
        $data = $params{data};
    }

    croak "Ext.Direct Event name is required"
        unless defined $name;

    my $self = bless { name => $name, data => $data }, $class;

    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# A stub for duck typing. Does nothing, returns failure.
#

sub run { '' }

### PUBLIC INSTANCE METHOD ###
#
# Returns hashref with Event data. Named so for compatibility with
# Exceptions and Requests.
#

sub result {
    my ($self) = @_;

    return {
        type => 'event',
        name => $self->name,
        data => $self->data,
    };
}

### PUBLIC INSTANCE METHODS ###
#
# Accessor methods
#

RPC::ExtDirect::Util::Accessor::create_accessors(
    simple => [qw/ name data /],
);

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Event - The way to pass data to client side

=head1 SYNOPSIS
 
 use RPC::ExtDirect;
 use RPC::ExtDirect::Event;
 
  sub foo : ExtDirect( pollHandler ) {
     my ($class) = @_;
 
     # Do something good, collect results to $good_data
     my $good_data = { ... };
 
     # Do something bad, collect results to $bad_data
     my $bad_data = [ ... ];
 
     # Return the data
     return (
                 RPC::ExtDirect::Event->new('good', $good_data),
                 RPC::ExtDirect::Event->new('bad',  $bad_data ),
            );
 }

=head1 DESCRIPTION

This module implements Event object that is used to return events or some kind
of data from EventProvider handlers to the client side.

Data can be anything that is serializable to JSON. No checks are made and it
is assumed that client side can understand format of the data sent with
Events.

Note that by default JSON will blow up if you try to feed it a blessed object
as data payload, and for very good reason: it is not obvious how to serialize
a self-contained object. Each case requires specific handling which is not
feasible in a framework like this; therefore no effort was made to support
serialization of blessed objects. If you know that your object is nothing
more than a hash containing simple scalar values and/or structures of
scalar values, create a copy like this:

 my $hashref = {};
 @$hashref{ keys %$object } = values %$object;

But in reality, it almost always is not as simple as this.

=head1 METHODS

=over 4

=item new($name, $data)

Creates a new Event object with event $name and some $data. Can also be passed
the arguments with a hashref, or a hash:

    my $event1 = RPC::ExtDirect::Event->new( 'foo', 'bar' );
    my $event2 = RPC::ExtDirect::Event->new({
        name => 'foo',
        data => 'bar',
    });
    my $event3 = RPC::ExtDirect::Event->new(
        name => 'foo',
        data => 'bar'
    );

All three ways are equal so use any one that is more convenient to you.

=item run()

Not intended to be called directly, provided for duck typing compatibility with
Exception and Request objects.

=item result()

Returns Event hashref in format supported by Ext.Direct client stack. Not
intended to be called directly.

=back

=head1 AUTHOR

Alex Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2013 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut
