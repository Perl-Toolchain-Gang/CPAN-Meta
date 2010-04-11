package CPAN::Meta::Feature;
use strict;
use warnings;

use CPAN::Meta::Prereqs;

sub new {
  my ($class, $identifier, $spec) = @_;

  my %guts = (
    identifier  => $identifier,
    description => $spec->{description},
    prereqs     => CPAN::Meta::Prereqs->new($spec->{prereqs}),
  );

  bless \%guts => $class;
}

sub identifier  { $_[0]{identifier}  }
sub description { $_[0]{description} }
sub prereqs     { $_[0]{prereqs} }

1;
