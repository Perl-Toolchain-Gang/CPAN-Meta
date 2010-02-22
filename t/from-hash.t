use strict;
use warnings;

use Version::Requirements;

use Test::More 0.88;

{
  my $string_hash = {
    Left   => 10,
    Shared => '>= 2, <= 9, != 7',
    Right  => 18,
  };

  my $req = Version::Requirements->from_string_hash($string_hash);

  is_deeply(
    $req->as_string_hash,
    $string_hash,
    "we can load from a string hash",
  );
}

done_testing;
