package CPAN::Meta::Prereq;
use strict;
use warnings;

use Carp qw(carp);
use Scalar::Util qw(blessed);
use Version::Requirements 0.101010; # accepts_module

sub __legal_phases { qw(configure build test runtime develop)   }
sub __legal_types  { qw(requires recommends suggests conflicts) }

# expect a prereq spec from META.json -- rjbs, 2010-04-11
sub new {
  my ($class, $prereq_spec) = @_;

  my %guts;
  PHASE: for my $phase ($class->__legal_phases) {
    next PHASE unless my $phase_spec = $prereq_spec->{ $phase };
    next PHASE unless keys %$phase_spec;

    TYPE: for my $type ($class->__legal_types) {
      next TYPE unless my $spec = $phase_spec->{ $type };
      next TYPE unless keys %$spec;

      $guts{$phase}{$type} = Version::Requirements->from_string_hash($spec);
    }
  }

  return bless \%guts => $class;
}

sub requirements_for {
  my ($self, $phase, $types) = @_;
  $types ||= 'requires';

  my $req = Version::Requirements->new;

  unless (grep { $phase eq $_ } $self->__legal_phases) {
    carp "requested requirements for unknown phase: $phase";
    return $req;
  }

  return $req unless $self->{ $phase };

  my %is_legal_type = map {; $_ => 1 } $self->__legal_types;

  for my $type (ref($types) ? @$types : $types) {
    unless ($is_legal_type{ $type }) {
      carp "requested requirements for unknown type: $phase";
      next;
    }

    next unless my $prereq = $self->{ $phase }{ $type };

    $req->add_requirements($prereq);
  }

  return $req;
}

sub with_merged_prereqs {
  my ($self, $other) = @_;

  my @other = blessed($other) ? $other : @$other;

  my @prereq_objs = ($self, @other);

  my %new_arg;

  for my $phase ($self->__legal_phases) {
    for my $type ($self->__legal_types) {
      my $req = Version::Requirements->new;

      for my $prereq (@prereq_objs) {
        my $this_req = $prereq->requirements_for($phase, $type);
        next unless $this_req->required_modules;

        $req->add_requirements($this_req);
      }

      next unless $req->required_modules;

      $new_arg{ $phase }{ $type } = $req->as_string_hash;
    }
  }

  return (ref $self)->new(\%new_arg);
}

sub as_string_hash {
  my ($self) = @_;

  my %hash;

  for my $phase ($self->__legal_phases) {
    for my $type ($self->__legal_types) {
      my $req = $self->requirements_for($phase, $type);
      next unless $req->required_modules;

      $hash{ $phase }{ $type } = $req->as_string_hash;
    }
  }

  return \%hash;
}

1;
