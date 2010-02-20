use strict;
use warnings;
package Version::Requirements;
# ABSTRACT: a set of version requirements for a CPAN dist

use Scalar::Util ();
use version ();

sub new {
  my ($class) = @_;
  return bless {} => $class;
}

sub add_minimum {
  my ($self, $name, $version) = @_;

  $version = version->parse($version)
    if defined $version and ! Scalar::Util::blessed($version);

  if (defined (my $oldver = $self->{ $name })) {
    if (defined $version) {
      $self->{ $name } = (sort { $b cmp $a } ($version, $oldver))[0];
    }
    return;
  }

  $self->{ $name } = $version;
}

sub minimums {
  my ($self) = @_;
  return { %$self };
}

sub minimum_strings {
  my ($self) = @_;

  my %return = map {; $_ => (defined $self->{$_} ? "$self->{$_}" : undef) }
               keys %$self;

  return \%return;
}

1;
