use strict;
use warnings;

use Version::Requirements;
use version;

use Test::More 0.88;

sub dies_ok (&@) {
  my ($code, $qr, $comment) = @_;

  my $lived = eval { $code->(); 1 };

  if ($lived) {
    fail("$comment: did not die");
  } else {
    like($@, $qr, $comment);
  }
}

{
  my $req_1 = Version::Requirements->new;
  $req_1->add_minimum(Left   => 10);
  $req_1->add_minimum(Shared => 2);
  $req_1->add_exclusion(Shared => 7);

  my $req_2 = Version::Requirements->new;
  $req_2->add_minimum(Shared => 1);
  $req_2->add_maximum(Shared => 9);
  $req_2->add_minimum(Right  => 18);

  $req_1->add_requirements($req_2);

  is_deeply(
    $req_1->as_string_hash,
    {
      Left   => 10,
      Shared => '>= 2, <= 9, != 7',
      Right  => 18,
    },
    "add requirements to an existing set of requirements",
  );
}

{
  my $req_1 = Version::Requirements->new;
  $req_1->add_minimum(Left   => 10);
  $req_1->add_minimum(Shared => 2);
  $req_1->add_exclusion(Shared => 7);

  my $req_2 = Version::Requirements->new;
  $req_2->add_minimum(Shared => 1);
  $req_2->add_maximum(Shared => 9);
  $req_2->add_minimum(Right  => 18);

  my $clone = $req_1->clone->add_requirements($req_2);

  is_deeply(
    $req_1->as_string_hash,
    {
      Left   => 10,
      Shared => '>= 2, != 7',
    },
    "clone/add_requirements does not affect lhs",
  );

  is_deeply(
    $req_2->as_string_hash,
    {
      Shared => '>= 1, <= 9',
      Right  => 18,
    },
    "clone/add_requirements does not affect rhs",
  );

  is_deeply(
    $clone->as_string_hash,
    {
      Left   => 10,
      Shared => '>= 2, <= 9, != 7',
      Right  => 18,
    },
    "clone and add_requirements",
  );

  $clone->clear_requirement('Shared');

  is_deeply(
    $clone->as_string_hash,
    {
      Left   => 10,
      Right  => 18,
    },
    "cleared the shared requirement",
  );
}

done_testing;
