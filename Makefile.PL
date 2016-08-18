use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker 6.17;

my %WriteMakefileArgs = (
  "ABSTRACT" => "the distribution metadata for a CPAN dist",
  "AUTHOR" => "David Golden <dagolden\@cpan.org>, Ricardo Signes <rjbs\@cpan.org>, Adam Kennedy <adamk\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "CPAN-Meta",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME" => "CPAN::Meta",
  "PREREQ_PM" => {
    "CPAN::Meta::Requirements" => "2.121",
    "CPAN::Meta::YAML" => "0.011",
    "Carp" => 0,
    "Encode" => 0,
    "Exporter" => 0,
    "File::Spec" => "0.80",
    "JSON::PP" => "2.27300",
    "Scalar::Util" => 0,
    "strict" => 0,
    "version" => "0.88",
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Dumper" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Basename" => 0,
    "File::Spec" => "0.80",
    "File::Spec::Functions" => 0,
    "File::Temp" => "0.20",
    "IO::Dir" => 0,
    "JSON::PP" => "2.27300",
    "Storable" => 0,
    "Test::More" => "0.88",
    "lib" => 0,
    "overload" => 0,
    "utf8" => 0,
    "vars" => 0
  },
  "VERSION" => "2.150011",
  "test" => {
    "TESTS" => "t/*.t t/parse-cpan-meta/*.t"
  }
);


my %FallbackPrereqs = (
  "CPAN::Meta::Requirements" => "2.121",
  "CPAN::Meta::YAML" => "0.011",
  "Carp" => 0,
  "Data::Dumper" => 0,
  "Encode" => 0,
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Basename" => 0,
  "File::Spec" => "0.80",
  "File::Spec::Functions" => 0,
  "File::Temp" => "0.20",
  "IO::Dir" => 0,
  "JSON::PP" => "2.27300",
  "Scalar::Util" => 0,
  "Storable" => 0,
  "Test::More" => "0.88",
  "lib" => 0,
  "overload" => 0,
  "strict" => 0,
  "utf8" => 0,
  "vars" => 0,
  "version" => "0.88",
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

$WriteMakefileArgs{INSTALLDIRS} = 'perl'
    if "$]" >= 5.010001 && "$]" <= 5.011000;

# Added by Dist::Zilla::Plugin::MakeMaker::Highlander
if ( $] < 5.012
  && ! $ENV{PERL_NO_HIGHLANDER}
  && ! ( $ENV{PERL_MM_OPT} && $ENV{PERL_MM_OPT} =~ /(?:INSTALL_BASE|PREFIX)/ )
  && ! grep { /INSTALL_BASE/ || /PREFIX/ } @ARGV
) {
    $WriteMakefileArgs{UNINST} = 1;
}

WriteMakefile(%WriteMakefileArgs);
