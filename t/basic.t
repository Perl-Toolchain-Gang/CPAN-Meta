use strict;
use warnings;

use Version::Requirements;
use version;

use Test::More 0.88;

{
  my $req = Version::Requirements->new;

  $req->add_minimum('Foo::Bar' => 10);
  $req->add_minimum('Foo::Bar' => 0);
  $req->add_minimum('Foo::Bar' => 2);

  $req->add_minimum('Foo::Baz' => version->declare('v1.2.3'));

  $req->add_minimum('Foo::Undef' => 0);

  is_deeply(
    $req->as_string_hash,
    {
      'Foo::Bar'   => 10,
      'Foo::Baz'   => 'v1.2.3',
      'Foo::Undef' => 0,
    },
    "some basic minimums",
  );
}

{
  my $req = Version::Requirements->new;

  $req->add_minimum(Foo => 1);
  $req->add_maximum(Foo => 2);

  is_deeply(
    $req->as_string_hash,
    {
      Foo => '>= 1, <= 2',
    },
    "min and max",
  );

  $req->add_maximum(Foo => 3);

  is_deeply(
    $req->as_string_hash,
    {
      Foo => '>= 1, <= 2',
    },
    "exclusions already outside range do not matter",
  );

  $req->add_exclusion(Foo => 1.5);

  is_deeply(
    $req->as_string_hash,
    {
      Foo => '>= 1, <= 2, != 1.5',
    },
    "exclusions",
  );

  $req->add_minimum(Foo => 1.6);

  is_deeply(
    $req->as_string_hash,
    {
      Foo => '>= 1.6, <= 2',
    },
    "exclusions go away when made irrelevant",
  );
}

{
  # ATTENTION
  # This might change in the future to generate '> 1, <= 2'
  # but there is no need to.  Just do not rely on it too much.
  my $req = Version::Requirements->new;

  $req->add_minimum(Foo => 1);
  $req->add_exclusion(Foo => 1);
  $req->add_maximum(Foo => 2);

  is_deeply(
    $req->as_string_hash,
    {
      Foo => '>= 1, <= 2, != 1',
    },
    "we can exclude an endpoint",
  );
}

{
  my $req = Version::Requirements->new;

  my $ok = eval {
    $req->add_minimum(Foo => 1);
    $req->add_exclusion(Foo => 1);
    $req->add_maximum(Foo => 1);
    1;
  };

  my $error = $@;

  ok(!$ok, "we can't exclude all values")
    or diag explain $req->as_string_hash;
}

done_testing;
