use strict;
use warnings;
package CPAN::Meta;

use Carp qw(confess);
use CPAN::Meta::Prereqs;

my @STRING_READERS = qw(
  abstract
  description
  dynamic_config
  generated_by
  name
  release_status
  version
);

BEGIN {
  no strict 'refs';
  for my $attr (@STRING_READERS) {
    *$attr = sub { $_[0]{ $attr } };
  }
}

my @LIST_READERS = qw(
  author
  keywords
  license
);

BEGIN {
  no strict 'refs';
  for my $attr (@LIST_READERS) {
    *$attr = sub {
      my $value = $_[0]{ $attr };
      return @$value if ref $value;
      return $value;
    };
  }
}

my @MAP_READERS = qw(
  meta_spec
  resources
  provides
  no_index

  prereqs
  optional_features
);

BEGIN {
  no strict 'refs';
  for my $attr (@MAP_READERS) {
    *$attr = sub {
      my $value = $_[0]{ $attr };
      return $value if $value;
      return {};
    };
  }
}

sub meta_spec_version {
  my ($self) = @_;
  return $self->meta_spec->{version};
}

sub effective_prereqs {
  my ($self, $features) = @_;
  $features ||= [];
  
  my $prereq = CPAN::Meta::Prereq->new($self->prereq);

  return $prereq unless @$features;

  my @other = map {;
    confess "unknown feature requested: $_"
      unless my $f = $self->optional_features->{$_};
    CPAN::Meta::Prereq->new($f->{prereq});
  } @$features;

  return $prereq->with_merged_prereqs(\@other);
}

1;
