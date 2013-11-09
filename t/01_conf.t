use strict;
use warnings;

use Test::More tests => 1;

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
    
    # Simple accessor, test existence and default value
    if ($accessor) {
        my $config = $cfg_class->new();
        my $value = eval { $config->$accessor() };
        
        is $@, '', "$accessor: simple accessor exists";
        
        if (defined $default) {
            is $value, $default, "$accessor: simple accessor default value matches";
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
