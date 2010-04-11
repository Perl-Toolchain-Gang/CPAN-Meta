use strict;
use warnings;
package CPAN::Meta;

use CPAN::Meta::Prereq;

my @STRING_READERS = qw(
  abstract
  description
  dynamic_config
  generated_by
  name
  release_status
  version
);

my @LIST_READERS = qw(
  author
  keywords
  license
);

my @MAP_READERS = qw(
  meta_spec
  resources
  provides
  no_index

  prereqs
  optional_features
);

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
