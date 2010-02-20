use strict;
use warnings;

use Version::Requirements;
use version;

use Test::More 0.88;

my $req = Version::Requirements->new;

$req->add_minimum('Foo::Bar' => 10);
$req->add_minimum('Foo::Bar' => undef);
$req->add_minimum('Foo::Bar' => 2);

$req->add_minimum('Foo::Baz' => version->declare('v1.2.3'));

$req->add_minimum('Foo::Undef' => undef);

is_deeply(
  $req->minimums,
  {
    'Foo::Bar'   => version->declare(10),
    'Foo::Baz'   => version->declare('v1.2.3'),
    'Foo::Undef' => undef,
  },
  "some basic minimums",
);

is_deeply(
  $req->minimum_strings,
  {
    'Foo::Bar'   => 10,
    'Foo::Baz'   => 'v1.2.3',
    'Foo::Undef' => undef,
  },
  "some basic minimums",
);

ok(
  ( ref $req->minimums->{'Foo::Bar'}),
  '->minimums returns version objects',
);

ok(
  ( ! ref $req->minimum_strings->{'Foo::Bar'}),
  '->minimum_strings returns strings',
);

done_testing;
