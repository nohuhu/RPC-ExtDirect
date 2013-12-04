use strict;
use warnings;

use Test::More tests => 67;

# A stub for testing global vars handling
package RPC::ExtDirect::API;

our $DEBUG;

package main;

BEGIN { use_ok 'RPC::ExtDirect::Config' }

my $cfg_class = 'RPC::ExtDirect::Config';
my $defs      = RPC::ExtDirect::Config::_get_definitions;

for my $def ( @$defs ) {
    my $accessor = $def->{accessor};
    my $package  = $def->{package};
    my $var      = $def->{var};
    my $type     = $def->{type};
    my $specific = $def->{setter};
    my $fallback = $def->{fallback};
    my $default  = $def->{default};
    my $have_def = exists $def->{default};
    
    # Simple accessor, test existence and default value
    if ($accessor) {
        my $config = $cfg_class->new();
        my $value = eval { $config->$accessor() };
        
        is $@, '', "$accessor: simple accessor exists";
        
        if ($have_def) {
            is $value, $default, "$accessor: simple accessor default value";
        }
    }
    
    # Defaultable accessor, check existence of specific getter
    if ($specific) {
        my $config = $cfg_class->new();
        
        eval { $config->$specific() };
        
        is $@, '', "$specific: defaultable specific accessor exists";
    }
    
    if ($fallback) {
        my $config = $cfg_class->new();
        
        eval { $config->$fallback() };
        
        is $@, '', "$fallback: defaultable fallback accessor exists";
    }
}

# Test cloning
my $config = $cfg_class->new();
my $clone  = $config->clone();

ok $config ne $clone,      "Clone is not self";
is_deeply $clone, $config, "Clone values match";

$SIG{__WARN__} = sub {};

package main;

is $config->debug_api, !1, "Default global var value";

$RPC::ExtDirect::API::DEBUG = 'foo';

$config->read_global_vars();

is $config->debug_api, 'foo', "Changed global var value";
