use strict;
use warnings;
package Version::Requirements;
# ABSTRACT: a set of version requirements for a CPAN dist

=head1 SYNOPSIS

  use Version::Requirements;

  my $build_requires = Version::Requirements->new;

  $build_requires->add_minimum('Library::Foo' => 1.208);

  $build_requires->add_minimum('Library::Foo' => 2.602);

  $build_requires->add_minimum('Module::Bar'  => 'v1.2.3');

  $METAyml->{build_requires} = $build_requires->as_string_hash;

=cut

use Carp ();
use Scalar::Util ();
use version ();

sub new {
  my ($class) = @_;
  return bless {} => $class;
}

sub _version_object {
  my ($self, $version) = @_;

  $version = (! defined $version)                ? version->parse(0)
           : (! Scalar::Util::blessed($version)) ? version->parse($version)
           :                                       $version;

  return $version;
}

BEGIN {
  for my $type (qw(minimum maximum exclusion exact_version)) {
    my $method = "with_$type";
    my $to_add = $type eq 'exact_version' ? $type : "add_$type";

    my $code = sub {
      my ($self, $name, $version) = @_;

      $version = $self->_version_object( $version );

      my $old = $self->{ $name } || 'Version::Requirements::_Spec::Range';

      $self->{ $name } = $old->$method($version);
    };
    
    no strict 'refs';
    *$to_add = $code;
  }
}

sub __modules   { keys %{ $_[ 0 ] } }
sub __entry_for { $_[0]{ $_[1] }    }

sub as_string_hash {
  my ($self) = @_;

  my %hash;
  for my $module ($self->__modules) {
    $hash{ $module } = $self->__entry_for($module)->as_string;
  }

  return \%hash;
}

{
  package
    Version::Requirements::_Spec::Exact;
  sub _new     { bless { version => $_[1] } => $_[0] }

  sub _accepts { return $_[0]{version} == $_[1] }

  sub as_string { return "== $_[0]{version}" }

  sub with_exact_version {
    my ($self, $version) = @_;

    return $self if $self->_accepts($version);

    Carp::confess("illegal requirements: unequal exact version specified");
  }

  sub with_minimum {
    my ($self, $minimum) = @_;
    return $self if $self->{version} >= $minimum;
    Carp::confess("illegal requirements: minimum above exact specification");
  }

  sub with_maximum {
    my ($self, $maximum) = @_;
    return $self if $self->{version} <= $maximum;
    Carp::confess("illegal requirements: maximum below exact specification");
  }

  sub with_exclusion {
    my ($self, $exclusion) = @_;
    return $self unless $exclusion == $self->{version};
    Carp::confess("illegal requirements: excluded exact specification");
  }
}

{
  package
    Version::Requirements::_Spec::Range;

  sub _self { ref($_[0]) ? $_[0] : (bless { } => $_[0]) }

  sub as_string {
    my ($self) = @_;

    return 0 if ! keys %$self;

    return "$self->{minimum}" if (keys %$self) == 1 and exists $self->{minimum};

    my @parts;
    push @parts, ">= $self->{minimum}" if exists $self->{minimum};
    push @parts, "<= $self->{maximum}" if exists $self->{maximum};
    push @parts, map {; "!= $_" } @{ $self->{exclusions} || [] };

    return join q{, }, @parts;
  }

  sub with_exact_version {
    my ($self, $version) = @_;
    $self = $self->_self;

    Carp::confess("illegal requirements: exact specification outside of range")
      unless $self->_accepts($version);

    return Version::Requirements::_Spec::Exact->_new($version);
  }

  sub _simplify {
    my ($self) = @_;

    if (defined $self->{minimum} and defined $self->{maximum}) {
      if ($self->{minimum} == $self->{maximum}) {
        Carp::confess("illegal requirements: excluded all values")
          if grep { $_ == $self->{minimum} } @{ $self->{exclusions} || [] };

        return Version::Requirements::_Spec::Exact->_new($self->{minimum})
      }

      Carp::confess("illegal requirements: minimum exceeds maximum")
        if $self->{minimum} > $self->{maximum};
    }

    # eliminate irrelevant exclusions
    if ($self->{exclusions}) {
      my %seen;
      @{ $self->{exclusions} } = grep {
        (! defined $self->{minimum} or $_ >= $self->{minimum})
        and
        (! defined $self->{maximum} or $_ <= $self->{maximum})
        and
        ! $seen{$_}++
      } @{ $self->{exclusions} };
    }

    return $self;
  }

  sub with_minimum {
    my ($self, $minimum) = @_;
    $self = $self->_self;

    # If $minimum is false, it's undef or 0, which cannot be meaningful as a
    # minimum.  -- rjbs, 2010-02-20
    return $self unless $minimum;

    if (defined (my $old_min = $self->{minimum})) {
      $self->{minimum} = (sort { $b cmp $a } ($minimum, $old_min))[0];
    } else {
      $self->{minimum} = $minimum;
    }

    return $self->_simplify;
  }

  sub with_maximum {
    my ($self, $maximum) = @_;
    $self = $self->_self;

    if (defined (my $old_max = $self->{maximum})) {
      $self->{maximum} = (sort { $a cmp $b } ($maximum, $old_max))[0];
    } else {
      $self->{maximum} = $maximum;
    }

    return $self->_simplify;
  }

  sub with_exclusion {
    my ($self, $exclusion) = @_;
    $self = $self->_self;

    push @{ $self->{exclusions} ||= [] }, $exclusion;

    return $self->_simplify;
  }

  sub _accepts {
    my ($self, $version) = @_;

    return if defined $self->{minimum} and $version < $self->{minimum};
    return if defined $self->{maximum} and $version > $self->{maximum};
    return if defined $self->{exclusions}
          and grep { $version == $_ } @{ $self->{exclusions} };

    return 1;
  }
}

1;
