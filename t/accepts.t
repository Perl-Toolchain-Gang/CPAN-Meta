use strict;
use warnings;

use Version::Requirements;

use Test::More 0.88;

# XXX: We're gonna violate us some encapsulation here and call us some private
# methods.  Y'all better just resign yourself to it.  -- rjbs, 2010-02-22
{
  my $req = Version::Requirements->new->add_minimum(Foo => 1);
  my $foo = $req->{Foo};

  ok($foo->_accepts(1));
  ok(! $foo->_accepts(0));
}

{
  my $req = Version::Requirements->new->add_maximum(Foo => 1);
  my $foo = $req->{Foo};

  ok($foo->_accepts(1));
  ok(! $foo->_accepts(2));
}

{
  my $req = Version::Requirements->new->add_exclusion(Foo => 1);
  my $foo = $req->{Foo};

  ok($foo->_accepts(0));
  ok(! $foo->_accepts(1));
}

done_testing;
