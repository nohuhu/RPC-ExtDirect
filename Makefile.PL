use 5.006000;
use ExtUtils::MakeMaker;

use strict;
use warnings;

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

my $MM_VERSION  = $ExtUtils::MakeMaker::VERSION;
my $github_repo = 'https://github.com/nohuhu/RPC-ExtDirect';

WriteMakefile(
    NAME              => 'RPC::ExtDirect',
    VERSION_FROM      => 'lib/RPC/ExtDirect.pm',
    ($MM_VERSION >= 6.55
        ? ( BUILD_REQUIRES => {
                'Test::More'            => '0.82',
            },
            PREREQ_PM => {
                'Attribute::Handlers'   => '0.87',
                'JSON'                  => '2.0',
            },
        )
        : ( PREREQ_PM => {
                'Test::More'            => '0.82',
                'Attribute::Handlers'   => '0.87',
                'JSON'                  => '2.0',
            },
        )
    ),

    ABSTRACT => 'Core Ext.Direct implementation for Perl',
    AUTHOR   => 'Alex Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',

    ($MM_VERSION >= 6.48
        ? ( MIN_PERL_VERSION => 5.006000, )
        : (),
    ),

    ($MM_VERSION >= 6.46
        ? ( META_MERGE => {
            resources   => {
                bugtracker  => "$github_repo/issues",
                repository  => $github_repo,
            },
           },
        )
        : ()
    ),
);

