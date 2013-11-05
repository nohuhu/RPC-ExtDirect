use strict;
use warnings;

use Test::More tests => 9;

BEGIN { use_ok 'RPC::ExtDirect::Serializer'; }

my $ser_class = 'RPC::ExtDirect::Serializer';

package Request;

sub new {
    my ($class, $params) = @_;

    return $params, $class;
}

package main;

my $serializer = $ser_class->new(request_class => 'Request');

my $req = $serializer->_request({ foo => 'bar' });

isa_ok $req, 'Request', "Honors request_class";

$serializer = $ser_class->new(
    exception_class_serialize => 'Request',
    exception_class           => 'Foo',
);

my $ex1 = $serializer->_exception({
    direction => 'serialize',
    foo       => 'bar',
});

isa_ok $ex1, 'Request', "Honors exception_class_serialize";

$serializer = $ser_class->new(
    exception_class_deserialize => 'Request',
    exception_class             => 'Foo',
);

my $ex2 = $serializer->_exception({
    direction => 'deserialize',
    foo       => 'bar',
});

isa_ok $ex2, 'Request', "Honors exception_class_deserialize";

$serializer = $ser_class->new( exception_class => 'Request' );

my $ex3 = $serializer->_exception({
    direction => 'serialize',
    foo       => 'bar',
});

isa_ok $ex3, 'Request', "Falls back to exception_class for serializer";

my $ex4 = $serializer->_exception({
    direction => 'deserialize',
    foo       => 'bar',
});

isa_ok $ex4, 'Request', "Falls back to exception_class for deserializer";

my $json_options = { canonical => 1 };

my $data     = { foo => 'foo', qux => 'qux', bar => 'bar' };
my $expected = '{"bar":"bar","foo":"foo","qux":"qux"}';

my $json = $ser_class->new(json_options => $json_options)->serialize(0, $data);

is $json, $expected, "Canonical output";

$data     = bless { foo => 'foo', };
$expected = q|{"action":null,"message":"encountered object 'main=HASH(blessed)', but neither allow_blessed nor convert_blessed settings are enabled","method":null,"tid":null,"type":"exception","where":"RPC::ExtDirect::Serializer"}|;

$json = $ser_class->new(debug => 1)->serialize(0, $data);

$json =~ s/HASH\([^\)]+\)/HASH(blessed)/;

is $json, $expected, 'Invalid data, exceptions on';

$expected = undef;

$json = $ser_class->new(debug => 1)->serialize(1, $data);

is $json, $expected, 'Ivalid data, exceptions off';

