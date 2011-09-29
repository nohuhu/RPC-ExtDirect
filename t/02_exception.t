use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 25;

BEGIN { use_ok 'RPC::ExtDirect::Exception'; }

package RPC::ExtDirect::Test;

use RPC::ExtDirect::Exception;

sub foo { RPC::ExtDirect::Exception->new(0, 'new fail'); }
sub bar { RPC::ExtDirect::Exception->new(1, 'bar fail'); }
sub qux { RPC::ExtDirect::Exception->new(1, 'qux fail', 'X->qux'); }

package main;

my $tests = [
    { method  => 'foo', ex => { type => 'exception', where => 'ExtDirect',
      message => 'An error has occured while processing request' }, },
    { method  => 'bar', ex => { type => 'exception',
      where   => 'RPC::ExtDirect::Test->bar', message => 'bar fail', }, },
    { method  => 'qux', ex => { type => 'exception',
      where   => 'X->qux', message => 'qux fail', }, },
];

for my $test ( @$tests ) {
    my $method = $test->{method};
    my $expect = $test->{ex};

    my $ex  = eval { RPC::ExtDirect::Test->$method() };

    is     $@,   '', "$method() new eval $@";
    ok     $ex,      "$method() exception not null";
    isa_ok $ex,  'RPC::ExtDirect::Exception';

    my $run = eval { $ex->run() };

    is  $@,   '', "$method() run eval $@";
    ok !$run,     "$method() run error returned";

    my $result = eval { $ex->result() };

    is        $@,      '',      "$method() result eval $@";
    ok        $result,          "$method() result not empty";
    is_deeply $result, $expect, "$method() exception deep"
        or BAIL_OUT( Data::Dumper->Dump( [ $result ], [ 'result' ] ) );
};

exit 0;
