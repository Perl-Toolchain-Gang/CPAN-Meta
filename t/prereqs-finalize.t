use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta::Prereqs;

sub dies_ok (&@) {
  my ($code, $qr, $comment) = @_;

  my $lived = eval { $code->(); 1 };

  if ($lived) {
    fail("$comment: did not die");
  } else {
    like($@, $qr, $comment);
  }
}

my $prereq_struct = {
  runtime => {
    requires => {
      'Config' => '1.234',
      'Cwd'    => '876.5',
      'IO::File'   => 0,
      'perl'       => '5.005_03',
    },
    recommends => {
      'Pod::Text' => 0,
      'YAML'      => '0.35',
    },
  },
  build => {
    requires => {
      'Test' => 0,
    },
  }
};

my $prereq = CPAN::Meta::Prereqs->new($prereq_struct);

isa_ok($prereq, 'CPAN::Meta::Prereqs');

$prereq->finalize;

pass('we survive finalization');

is_deeply($prereq->as_string_hash, $prereq_struct, '...and still round-trip');

$prereq->requirements_for(qw(runtime requires))->add_minimum(Cwd => 10);

pass('...we can add a minimum if it has no effect');

dies_ok
  { $prereq->requirements_for(qw(runtime requires))->add_minimum(Cwd => 1000) }
  qr{finalized req},
  '...but we die if it would alter a finalized prereqs';

$prereq->requirements_for(qw(develop suggests));

pass('...we can get a V:R object for a previously unconfigured phase');

dies_ok
  { $prereq->requirements_for(qw(develop suggests))->add_minimum(Foo => 1) }
  qr{finalized req},
  '...but we die if we try to put anything in it';

done_testing;
