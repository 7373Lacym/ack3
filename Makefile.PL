package main;

require 5.008008;

use strict;
use warnings;
use ExtUtils::MakeMaker;

my $debug_mode = (grep { $_ eq '--debug' } @ARGV) ? '--debug' : '';

my %parms = (
    NAME                => 'ack',
    AUTHOR              => 'Andy Lester <andy@petdance.com>',
    ABSTRACT            => 'A grep-like program for searching source code',
    VERSION_FROM        => 'lib/App/Ack.pm',

    EXE_FILES               => [ 'ack' ],

    PREREQ_PM => {
        'Carp'              => '1.04',
        'Cwd'               => '3.00',
        'Errno'             => 0,
        'File::Basename'    => '1.00015',
        'File::Next'        => '1.16',
        'File::Spec'        => '3.00',
        'File::Temp'        => '0.19', # For newdir()
        'Getopt::Long'      => '2.38',
        'Pod::Usage'        => '1.26',
        'Term::ANSIColor'   => '1.10',
        'Test::Harness'     => '2.50', # Something reasonably newish
        'Test::More'        => '0.98', # For subtest()
        'Text::ParseWords'  => '3.1',
        ( $^O eq 'MSWin32' ? ('Win32::ShellQuote' => '0.002001') : () ),
    },
    MAN3PODS            => {}, # no need for man pages for any of the .pm files
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'ack-2* nytprof* stderr.log stdout.log completion.*' },
);

if ( $ExtUtils::MakeMaker::VERSION =~ /^\d\.\d\d$/ and $ExtUtils::MakeMaker::VERSION > 6.30 ) {
    $parms{LICENSE} = 'artistic_2';
}

if ( $ExtUtils::MakeMaker::VERSION ge '6.46' ) {
    $parms{META_MERGE} = {
        resources => {
            homepage    => 'https://beyondgrep.com/',
            bugtracker  => 'https://github.com/petdance/ack2',
            license     => 'http://www.perlfoundation.org/artistic_license_2_0',
            repository  => 'git://github.com/petdance/ack2.git',
            MailingList => 'https://groups.google.com/group/ack-users',
        }
    };
}

if ( $ExtUtils::MakeMaker::VERSION ge '6.48' ) {
    $parms{MIN_PERL_VERSION} = 5.008008;
}

WriteMakefile( %parms );

package MY;

# suppress EU::MM test rule
sub MY::test {
    return '';
}

sub MY::postamble {
    my $postamble = sprintf(<<'MAKE_FRAG', $debug_mode);
ACK    = ack
ALL_PM = \
    lib/App/Ack.pm \
    \
    lib/App/Ack/Resource.pm \
    lib/App/Ack/Resources.pm \
    lib/App/Ack/ConfigDefault.pm \
    lib/App/Ack/ConfigFinder.pm \
    lib/App/Ack/ConfigLoader.pm \
    lib/App/Ack/Filter.pm \
    \
    lib/App/Ack/Filter/Collection.pm \
    lib/App/Ack/Filter/Default.pm \
    lib/App/Ack/Filter/Extension.pm \
    lib/App/Ack/Filter/ExtensionGroup.pm \
    lib/App/Ack/Filter/FirstLineMatch.pm \
    lib/App/Ack/Filter/Inverse.pm \
    lib/App/Ack/Filter/Is.pm \
    lib/App/Ack/Filter/IsGroup.pm \
    lib/App/Ack/Filter/IsPath.pm \
    lib/App/Ack/Filter/IsPathGroup.pm \
    lib/App/Ack/Filter/Match.pm \
    lib/App/Ack/Filter/MatchGroup.pm \

TEST_VERBOSE=0
TEST_FILES=t/*.t t/lib/*.t
TEST_XT_FILES=xt/*.t

.PHONY: tags critic

tags:
	ctags -f tags --recurse --totals \
		--exclude=blib \
		--exclude=.git \
		--exclude='*~' \
		--exclude=ack-standalone \
		--languages=Perl --langmap=Perl:+.t \

critic:
	perlcritic -1 -q -profile perlcriticrc $(ACK) $(ALL_PM) t/*.t t/lib/*.t xt/*.t

ack-standalone : $(ACK) $(ALL_PM) squash Makefile
	$(PERL) squash $(ACK) $(ALL_PM) File::Next %s > ack-standalone
	$(FIXIN) ack-standalone
	-$(NOECHO) $(CHMOD) $(PERM_RWX) ack-standalone
	$(PERL) -c ack-standalone

bininst : $(ACK)
	$(CP) $(ACK) ~/bin/ack2
	$(CP) ackrc ~/.ack2rc

test: test_classic test_standalone

fulltest: test_classic test_standalone test_xt

test_classic: all
	$(FULLPERLRUN) t/runtests.pl 0 $(TEST_VERBOSE) "$(INST_LIB)" "$(INST_ARCHLIB)" $(TEST_FILES)

test_standalone: all ack-standalone
	$(FULLPERLRUN) t/runtests.pl 1 $(TEST_VERBOSE) "$(INST_LIB)" "$(INST_ARCHLIB)" $(TEST_FILES)

test_xt: all
	$(FULLPERLRUN) t/runtests.pl 0 $(TEST_VERBOSE) "$(INST_LIB)" "$(INST_ARCHLIB)" $(TEST_XT_FILES)

PROF_ARGS = -Mblib blib/script/ack foo ~/parrot

nytprof: all
	$(PERL) -d:NYTProf $(PROF_ARGS) >> /dev/null 2>&1
	nytprofhtml

TIMER_ARGS=foo ~/parrot > /dev/null
time-ack196:
	time $(PERL) ./garage/ack196 --noenv $(TIMER_ARGS)

time-ack202:
	time $(PERL) ./garage/ack202 --noenv $(TIMER_ARGS)

time-ack20301:
	time $(PERL) ./garage/ack20301 --noenv $(TIMER_ARGS)

time-ack20302:
	time $(PERL) ./garage/ack20302 --noenv $(TIMER_ARGS)

time-head: ack-standalone
	time $(PERL) ./ack-standalone --noenv $(TIMER_ARGS)

timings: ack-standalone
	./dev/timings.pl

completion.bash: pm_to_blib
	./dev/generate-completion-scripts.pl completion.bash

completion.zsh: pm_to_blib
	./dev/generate-completion-scripts.pl completion.zsh

MAKE_FRAG

    return $postamble;
}

1;