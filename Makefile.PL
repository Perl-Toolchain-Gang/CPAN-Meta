#!/usr/bin/perl

# A stub Makefile.PL so casual developers can run the tests.
#
# Real development should happen via Dist::Zilla

use lib 'inc';
use ExtUtils::MakeMaker::Dist::Zilla::Develop;

WriteMakefile(
    NAME => 'CPAN::Meta'
);
