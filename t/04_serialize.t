use strict;
use warnings;

use Test::More tests => 2;

BEGIN { use_ok 'RPC::ExtDirect::Serialize'; }

local $RPC::ExtDirect::Serialize::DEBUG = 1;

my $data   = { foo => 'foo', qux => 'qux', bar => 'bar' };
my $expect = '{"bar":"bar","foo":"foo","qux":"qux"}';

my $json = RPC::ExtDirect::Serialize->serialize($data);

is $json, $expect, "Canonical output";

exit 0;
