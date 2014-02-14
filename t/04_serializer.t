use strict;
use warnings;

use Test::More tests => 9;

use RPC::ExtDirect::Config;

use RPC::ExtDirect::Serializer;

my $cfg_class = 'RPC::ExtDirect::Config';
my $ser_class = 'RPC::ExtDirect::Serializer';

package Request;

sub new {
    my ($class, $params) = @_;

    return $params, $class;
}

package main;

my $config     = $cfg_class->new(request_class => 'Request');
my $serializer = $ser_class->new(config => $config);

my $req = $serializer->_request({ foo => 'bar' });

isa_ok $req, 'Request', "Honors request_class";

$config     = $cfg_class->new(
    exception_class_serialize => 'Request',
    exception_class           => 'Foo',
);
$serializer = $ser_class->new(config => $config);

my $ex1 = $serializer->_exception({
    direction => 'serialize',
    foo       => 'bar',
});

isa_ok $ex1, 'Request', "Honors exception_class_serialize";

$config     = $cfg_class->new(
    exception_class_deserialize => 'Request',
    exception_class             => 'Foo',
);
$serializer = $ser_class->new(config => $config);

my $ex2 = $serializer->_exception({
    direction => 'deserialize',
    foo       => 'bar',
});

isa_ok $ex2, 'Request', "Honors exception_class_deserialize";

$config     = $cfg_class->new( exception_class => 'Request' );
$serializer = $ser_class->new( config          => $config   );

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

$config = $cfg_class->new(json_options => $json_options);

my $json = $ser_class->new(config => $config)->serialize(0, $data);

is $json, $expected, "Canonical output";

$data     = bless { foo => 'foo', };
$expected = q|{"action":null,"message":"encountered object 'main=HASH(blessed)', but neither allow_blessed nor convert_blessed settings are enabled","method":null,"tid":null,"type":"exception","where":"RPC::ExtDirect::Serializer"}|;

for my $option ( qw/ debug verbose_exceptions / ) {
    # verbose_exceptions will turn on verboseness only,
    # but we also need debug to produce canonical JSON
    # for comparison, or the test will never pass :)
    my $config = $cfg_class->new($option => 1, debug => 1);

    my $json = $ser_class->new(config => $config)->serialize(0, $data);

    $json =~ s/HASH\([^\)]+\)/HASH(blessed)/;

    is $json, $expected, "Invalid data, $option on";
}

$expected = undef;

$json = $ser_class->new(debug => 1)->serialize(1, $data);

is $json, $expected, 'Ivalid data, exceptions off';

