use 5.012000;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'RPC::ExtDirect',
    VERSION_FROM      => 'lib/RPC/ExtDirect.pm', # finds $VERSION
    ($ExtUtils::MakeMaker::VERSION >= 6.55
        ? ( BUILD_REQUIRES => {
                'Test::More' => 0,
                'Test::Pod'  => 0,
            },
            PREREQ_PM => {
                'Attribute::Handlers' => '0.87',
                'JSON'                => '2.0',
            },
        )
        : ( PREREQ_PM => {
                'Test::More'            => 0,
                'Test::Pod'             => 0,
                'Attribute::Handlers'   => '0.87',
                'JSON'                  => '2.0',
            },
        )
    ),
    ($] >= 5.005 ?
      (ABSTRACT => 'Ext.Direct implementation for Perl',
       AUTHOR   => 'Alexander Tokarev <tokarev@cpan.org>',
       LICENSE  => 'perl',
      ) : ()),

    ($ExtUtils::MakeMaker::VERSION >= 6.46
        ? ( META_MERGE => {
            resources   => {
                bugtracker  => 'http://github.com/nohuhu/RPC-ExtDirect/issues',
                repository  => 'http://github.com/nohuhu/RPC-ExtDirect',
            },
           },
        )
        : ()
    ),

    MIN_PERL_VERSION => 5.012000,
);
