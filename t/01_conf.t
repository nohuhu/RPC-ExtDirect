use strict;
use warnings;

use Test::More tests => 9;

BEGIN { use_ok 'RPC::ExtDirect::Config'; }

my @methods = qw(router_path poll_path remoting_var polling_var);

my %expected_get_for = (
    router_path  => '/extdirectrouter',
    poll_path    => '/extdirectevents',
    remoting_var => 'Ext.app.REMOTING_API',
    polling_var  => 'Ext.app.POLLING_API',
);

for my $method ( @methods ) {
    my $get_sub  = 'get_'.$method;

    my $result   = eval { RPC::ExtDirect::Config->$get_sub() };
    my $expected = $expected_get_for{ $method };

    is $@,      '',        "$method get eval $@";
    is $result, $expected, "$method get result";
};

