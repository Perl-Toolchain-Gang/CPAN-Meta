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

=head1 DESCRIPTION

A Version::Requirements object models a set of version constraints like those
specified in the F<META.yml> or F<META.json> files in CPAN distributions.  It
can be built up by adding more and more constraints, and it will reduce them to
the simplest representation.

Logically impossible constraints will be identified immediately by thrown
exceptions.

=cut

use Carp ();
use Scalar::Util ();
use version ();

=method new

  my $req = Version::Requirements->new;

This returns a new Version::Requirements object.  It ignores any arguments
given.

=cut

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

=method add_minimum

  $req->add_minimum( $module => $version );

This adds a new minimum version requirement.  If the new requirement is
redundant to the existing specification, this has no effect.

Minimum requirements are inclusive.  C<$version> is required, along with any
greater version number.

=method add_maximum

  $req->add_minimum( $module => $version );

This adds a new maximum version requirement.  If the new requirement is
redundant to the existing specification, this has no effect.

Maximum requirements are inclusive.  No version strictly greater than the given
version is allowed.

=method add_exclusion

  $req->add_exclusion( $module => $version );

This adds a new excluded version.  For example, you might use these three
method calls:

  $req->add_minimum( $module => '1.00' );
  $req->add_maximum( $module => '1.82' );

  $req->add_exclusion( $module => '1.75' );

Any version between 1.00 and 1.82 inclusive would be acceptable, except for
1.75.

=method exact_version

  $req->exact_version( $module => $version );

This sets the version required for the given module to I<exactly> the given
version.  No other version would be considered acceptable.

=cut

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

=method add_requirements

  $req->add_requirements( $another_req_object );

This method adds all the requirements in the given Version::Requirements object
to the requirements object on which it was called.  If there are any conflicts,
an exception is thrown.

=cut

sub add_requirements {
  my ($self, $req) = @_;

  for my $module ($req->required_modules) {
    my $modifiers = $req->__entry_for($module)->as_modifiers;
    for my $modifier (@$modifiers) {
      my ($method, @args) = @$modifier;
      $self->$method($module => @args);
    };
  }

  return $self;
}

=method clear_requirement

  $req->clear_requirement( $module );

This removes the requirement for a given module from the object.

=cut

sub clear_requirement {
  my ($self, $module) = @_;
  delete $self->{ $module };
}

=method required_modules

This method returns a list of all the modules for which requirements have been
specified.

=cut

sub required_modules { keys %{ $_[ 0 ] } }

=method clone

  $req->clone;

This method returns a clone of the invocant.  The clone and the original object
can then be changed independent of one another.

=cut

sub clone {
  my ($self) = @_;
  my $new = (ref $self)->new;

  return $new->add_requirements($self);
}

sub __entry_for {
  $_[0]{ $_[1] }
}

=method as_string_hash

This returns a reference to a hash describing the requirements using the
strings in the F<META.yml> specification.

For example after the following program:

  my $req = Version::Requirements->new;

  $req->add_minimum('Version::Requirements' => 0.102);

  $req->add_minimum('Library::Foo' => 1.208);

  $req->add_maximum('Library::Foo' => 2.602);

  $req->add_minimum('Module::Bar'  => 'v1.2.3');

  $req->add_exclusion('Module::Bar'  => 'v1.2.8');

  $req->exact_version('Xyzzy'  => '6.01');

  my $hashref = $req->as_string_hash;

C<$hashref> would contain:

  {
    'Version::Requirements' => '0.102',
    'Library::Foo' => '>= 1.208, <= 2.206',
    'Module::Bar'  => '>= v1.2.3, != v1.2.8',
    'Xyzzy'        => '== 6.01',
  }

=cut

sub as_string_hash {
  my ($self) = @_;

  my %hash = map {; $_ => $self->{$_}->as_string } keys %$self;

  return \%hash;
}

=method from_string_hash

  my $req = Version::Requirements->from_string_hash( \%hash );

This is an alternate constructor for a Version::Requirements object.  It takes
a hash of module names and version requirement strings and returns a new
Version::Requirements object.

=cut

my %methods_for_op = (
  '==' => [ qw(exact_version) ],
  '!=' => [ qw(add_exclusion) ],
  '>=' => [ qw(add_minimum)   ],
  '<=' => [ qw(add_maximum)   ],
  '>'  => [ qw(add_minimum add_exclusion) ],
  '<'  => [ qw(add_maximum add_exclusion) ],
);

sub from_string_hash {
  my ($class, $hash) = @_;

  my $self = $class->new;

  for my $module (keys %$hash) {
    my @parts = split qr{\s*,\s*}, $hash->{ $module };
    for my $part (@parts) {
      my ($op, $ver) = split /\s+/, $part, 2;

      if (! defined $ver) {
        $self->add_minimum($module => $op);
      } else {
        Carp::confess("illegal requirement string: $hash->{ $module }")
          unless my $methods = $methods_for_op{ $op };

        $self->$_($module => $ver) for @$methods;
      }
    }
  }

  return $self;
}

##############################################################

{
  package
    Version::Requirements::_Spec::Exact;
  sub _new     { bless { version => $_[1] } => $_[0] }

  sub _accepts { return $_[0]{version} == $_[1] }

  sub as_string { return "== $_[0]{version}" }

  sub as_modifiers { return [ [ exact_version => $_[0]{version} ] ] }

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

##############################################################

{
  package
    Version::Requirements::_Spec::Range;

  sub _self { ref($_[0]) ? $_[0] : (bless { } => $_[0]) }

  sub as_modifiers {
    my ($self) = @_;
    my @mods;
    push @mods, [ add_minimum => $self->{minimum} ] if exists $self->{minimum};
    push @mods, [ add_maximum => $self->{maximum} ] if exists $self->{maximum};
    push @mods, map {; [ add_exclusion => $_ ] } @{$self->{exclusions} || []};
    return \@mods;
  }

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
