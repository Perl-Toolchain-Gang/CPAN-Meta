use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta::Prereq;

my $prereq = CPAN::Meta::Prereq->new({
  runtime => {
    requires => {
      'Config' => 0,
      'Cwd'    => 0,
      'Data::Dumper' => 0,
      'ExtUtils::Install' => 0,
      'File::Basename' => 0,
      'File::Compare'  => 0,
      'File::Copy' => 0,
      'File::Find' => 0,
      'File::Path' => 0,
      'File::Spec' => 0,
      'IO::File'   => 0,
      'perl'       => '5.005_03',
    },
    recommends => {
      'Archive::Tar' => '1.00',
      'ExtUtils::Install' => 0.3,
      'ExtUtils::ParseXS' => 2.02,
      'Pod::Text' => 0,
      'YAML' => 0.35,
    },
  },
  build => {
    requires => {
      'Test' => 0,
    },
  }
});

isa_ok($prereq, 'CPAN::Meta::Prereq');

{
  my $req = $prereq->requirements_for('runtime');
  my @req_mod = $req->required_modules;

  ok(
    (grep { 'Cwd' eq $_ } @req_mod),
    "we got the runtime requirements",
  );

  ok(
    (! grep { 'YAML' eq $_ } @req_mod),
    "...but not the runtime recommendations",
  );

  ok(
    (! grep { 'Test' eq $_ } @req_mod),
    "...nor the build requirements",
  );
}

{
  my $req = $prereq->requirements_for('runtime', [ qw(requires recommends) ]);
  my @req_mod = $req->required_modules;

  ok(
    (grep { 'Cwd' eq $_ } @req_mod),
    "we got the runtime requirements",
  );

  ok(
    (grep { 'YAML' eq $_ } @req_mod),
    "...and the runtime recommendations",
  );

  ok(
    (! grep { 'Test' eq $_ } @req_mod),
    "...but not the build requirements",
  );
}

{
  my $req = $prereq->requirements_for('runtime', [ qw(suggests) ]);
  my @req_mod = $req->required_modules;

  is(@req_mod, 0, "empty set of runtime/suggests requirements");
}

{
  my $req = $prereq->requirements_for('develop', [ qw(suggests) ]);
  my @req_mod = $req->required_modules;

  is(@req_mod, 0, "empty set of develop/suggests requirements");
}

done_testing;

