use strict;
use warnings;
no  warnings 'uninitialized';

use Test::More tests => 11;

use lib 't/lib';
use RPC::ExtDirect::Test::PollProvider;

BEGIN { use_ok 'RPC::ExtDirect::EventProvider'; }

local $RPC::ExtDirect::EventProvider::DEBUG = 1;

my $tests = eval do { local $/; <DATA>; }           ## no critic
    or die "Can't eval DATA: '$@'";

for my $test ( @$tests ) {
    my $name     = $test->{name};
    my $password = $test->{password};
    my $expect   = $test->{result};

    local $RPC::ExtDirect::Test::PollProvider::WHAT_YOURE_HAVING
            = $password;

    my $result = eval { RPC::ExtDirect::EventProvider->poll() };

    # Remove whitespace
    s/\s//g for ( $expect, $result );

    is $@,      '',      "$name eval $@";
    is $result, $expect, "$name result";
};

exit 0;

__DATA__
[
    { name   => 'Two events', password => 'Usual, please',
      result => q|[{"data":["foo"],|.
                q|  "name":"foo_event",|.
                q|  "type":"event"},|.
                q| {"data":{"foo":"bar"},|.
                q|  "name":"bar_event",|.
                q|  "type":"event"}]|,
    },
    { name   => 'One event', password => 'Ein kaffe bitte',
      result => q|{"data":"Uno cappuccino, presto!",|.
                q| "name":"coffee",|.
                q| "type":"event"}|,
    },
    { name   => 'Failed method', password => 'Whiskey, straight away!',
      result => q|{"data":"","name":"__NONE__","type":"event"}|,
    },
    { name     => 'No events at all',
      password => "But that's not on the menu!",
      result   => q|{"data":"","name":"__NONE__","type":"event"}|,
    },
    { name     => 'Invalid Event provider output',
      password => "Hey man! There's a roach in my soup!",
      result   => q|{"data":"","name":"__NONE__","type":"event"}|,
    },
]
