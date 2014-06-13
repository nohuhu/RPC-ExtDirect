use 5.006000;
use ExtUtils::MakeMaker;

# Add the `devtest` target to run regression and POD tests in one go
sub MY::postamble {
    return <<'END';
devtest :
	REGRESSION_TESTS=1 POD_TESTS=1 $(MAKE) test

END
}

# Override `disttest` so it would behave as `devtest`
sub MY::dist_test {
	return <<'END';
disttest : distdir
	cd $(DISTVNAME) && $(ABSPERLRUN) Makefile.PL
	cd $(DISTVNAME) && $(MAKE) $(PASTHRU)
	cd $(DISTVNAME) && $(MAKE) devtest $(PASTHRU)

END
}

my $MMVersion = $ExtUtils::MakeMaker::VERSION;

WriteMakefile(
    NAME              => 'RPC::ExtDirect',
    VERSION_FROM      => 'lib/RPC/ExtDirect.pm',
    ($MMVersion >= 6.55
        ? ( BUILD_REQUIRES => {
                'Test::More' => '0.48',
            },
            PREREQ_PM => {
                'Attribute::Handlers' => '0.87',
                'JSON'                => '2.0',
            },
        )
        : ( PREREQ_PM => {
                'Test::More'            => '0.48',
                'Attribute::Handlers'   => '0.87',
                'JSON'                  => '2.0',
            },
        )
    ),

    ABSTRACT => 'Core Ext.Direct implementation',
    AUTHOR   => 'Alex Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',

    ($MMVersion >= 6.46
        ? ( META_MERGE => {
            resources   => {
                bugtracker  => 'http://github.com/nohuhu/RPC-ExtDirect/issues',
                repository  => 'http://github.com/nohuhu/RPC-ExtDirect',
            },
           },
        )
        : ()
    ),

    MIN_PERL_VERSION => 5.006000,
);

