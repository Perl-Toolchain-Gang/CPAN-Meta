use strict;
use warnings;
package CPAN::Meta;

use Carp qw(confess);
use CPAN::Meta::Prereqs;

BEGIN {
  my @STRING_READERS = qw(
    abstract
    description
    dynamic_config
    generated_by
    name
    release_status
    version
  );

  no strict 'refs';
  for my $attr (@STRING_READERS) {
    *$attr = sub { $_[0]{ $attr } };
  }
}

BEGIN {
  my @LIST_READERS = qw(
    author
    keywords
    license
  );

  no strict 'refs';
  for my $attr (@LIST_READERS) {
    *$attr = sub {
      my $value = $_[0]{ $attr };
      return @$value if ref $value;
      return $value;
    };
  }
}

sub authors  { $_[0]->author }
sub licenses { $_[0]->license }

BEGIN {
  my @MAP_READERS = qw(
    meta-spec
    resources
    provides
    no_index

    prereqs
    optional_features
  );

  no strict 'refs';
  for my $attr (@MAP_READERS) {
    (my $subname = $attr) =~ s/-/_/;
    *$subname = sub {
      my $value = $_[0]{ $attr };
      return $value if $value;
      return {};
    };
  }
}

sub new {
  my ($class, $struct) = @_;

  bless $struct => $class;
}

sub meta_spec_version {
  my ($self) = @_;
  return $self->meta_spec->{version};
}

sub effective_prereqs {
  my ($self, $features) = @_;
  $features ||= [];
  
  my $prereq = CPAN::Meta::Prereqs->new($self->prereqs);

  return $prereq unless @$features;

  my @other = map {;
    confess "unknown feature requested: $_"
      unless my $f = $self->optional_features->{$_};
    CPAN::Meta::Prereqs->new($f->{prereqs});
  } @$features;

  return $prereq->with_merged_prereqs(\@other);
}

1;
