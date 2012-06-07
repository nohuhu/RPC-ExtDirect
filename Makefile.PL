use 5.006000;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'RPC::ExtDirect',
    VERSION_FROM      => 'lib/RPC/ExtDirect.pm', # finds $VERSION

    BUILD_REQUIRES    => {
        'Test::More'            => 0,
        'Test::Pod'             => 0,
    },

    PREREQ_PM         => {
        'Attribute::Handlers'   => '0.87',
        'JSON'                  => '2.0',
    }, # e.g., Module::Name => 1.1

    ABSTRACT => 'Ext.Direct implementation for Sencha ExtJS framework',
    AUTHOR   => 'Alexander Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',

    META_MERGE => {
        resources   => {
            bugtracker  => 'http://github.com/nohuhu/RPC-ExtDirect/issues',
            repository  => 'http://github.com/nohuhu/RPC-ExtDirect',
        },
    },

);

