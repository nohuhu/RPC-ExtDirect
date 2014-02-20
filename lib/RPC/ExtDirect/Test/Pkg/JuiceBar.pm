#
# WARNING WARNING WARNING
#
# DO NOT CHANGE ANYTHING IN THIS MODULE. OTHERWISE, A LOT OF API 
# AND OTHER TESTS MAY BREAK.
#
# This module is here to test certain behaviors. If you need
# to test something else, add another test module.
# It's that simple.
#

package RPC::ExtDirect::Test::Pkg::JuiceBar;

use strict;
use warnings;
no  warnings 'uninitialized';

use base 'RPC::ExtDirect::Test::Pkg::Foo';

use RPC::ExtDirect;

use Carp;
use Data::Dumper;

our $CHEAT = 0;

# This one croaks merrily
sub bar_foo : ExtDirect(4) { croak 'bar foo!' }

# Return number of passed arguments
sub bar_bar : ExtDirect(5) { shift; return scalar @_; }

# This is a form handler
sub bar_baz : ExtDirect( formHandler ) {
    my ($class, %param) = @_;

    # Simulate uploaded file handling
    my $uploads = $param{file_uploads};
    return \%param unless $uploads;

    # Return 'uploads' data
    my $response = "The following files were processed:\n";
    for my $upload ( @$uploads ) {
        my $name = $upload->{basename};
        my $type = $upload->{type};
        my $size = $upload->{size};

        # CTI::Test somehow uploads files so that
        # they are 2 bytes shorter than actual size
        # This allows for the same test results to be
        # applied across all gateways and test frameworks
        #
        # Well, in all truthiness this should be the opposite
        # but CGI::Test was there first...
        $size -= 2 if $CHEAT;

        my $ok = (defined $upload->{handle} &&
                          $upload->{handle}->opened) ? "ok" : "not ok";

        $response .= "$name $type $size $ok\n";
    };

    delete $param{file_uploads};
    $param{upload_response} = $response;

    return \%param;
}

1;
