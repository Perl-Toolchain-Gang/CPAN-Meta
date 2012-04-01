use strict;
use warnings;
package CPAN::Meta::Requirements;
# VERSION
# ABSTRACT: a set of version requirements for a CPAN dist

=head1 SYNOPSIS

  use CPAN::Meta::Requirements;

  my $build_requires = CPAN::Meta::Requirements->new;

  $build_requires->add_minimum('Library::Foo' => 1.208);

  $build_requires->add_minimum('Library::Foo' => 2.602);

  $build_requires->add_minimum('Module::Bar'  => 'v1.2.3');

  $METAyml->{build_requires} = $build_requires->as_string_hash;

=head1 DESCRIPTION

A CPAN::Meta::Requirements object models a set of version constraints like
those specified in the F<META.yml> or F<META.json> files in CPAN distributions.
It can be built up by adding more and more constraints, and it will reduce them
to the simplest representation.

Logically impossible constraints will be identified immediately by thrown
exceptions.

=cut

use Carp ();
use Scalar::Util ();
use version 0.77 (); # the ->parse method

=method new

  my $req = CPAN::Meta::Requirements->new;

This returns a new CPAN::Meta::Requirements object.  It takes an optional
hash reference argument.  The following keys are supported:

=for :list
* <bad_version_hook> -- if provided, when a version cannot be parsed into
a version object, this code reference will be called with the invalid version
string as an argument.  It must return a valid version object.

All other keys are ignored.

=cut

my @valid_options = qw( bad_version_hook );

sub new {
  my ($class, $options) = @_;
  $options ||= {};
  Carp::croak "Argument to $class\->new() must be a hash reference"
    unless ref $options eq 'HASH';
  my %self = map {; $_ => $options->{$_}} @valid_options;

  return bless \%self => $class;
}

sub _version_object {
  my ($self, $version) = @_;

  my $vobj;

  eval {
    $vobj  = (! defined $version)                ? version->parse(0)
           : (! Scalar::Util::blessed($version)) ? version->parse($version)
           :                                       $version;
  };

  if ( my $err = $@ ) {
    my $hook = $self->{bad_version_hook};
    $vobj = eval { $hook->($version) }
      if ref $hook eq 'CODE';
    unless (Scalar::Util::blessed($vobj) && $vobj->isa("version")) {
      $err =~ s{ at .* line \d+.*$}{};
      die "Can't convert '$version': $err";
    }
  }

  # ensure no leading '.'
  if ( $vobj =~ m{\A\.} ) {
    $vobj = version->parse("0$vobj");
  }

  # ensure normal v-string form
  if ( $vobj->is_qv ) {
    $vobj = version->parse($vobj->normal);
  }

  return $vobj;
}

=method add_minimum

  $req->add_minimum( $module => $version );

This adds a new minimum version requirement.  If the new requirement is
redundant to the existing specification, this has no effect.

Minimum requirements are inclusive.  C<$version> is required, along with any
greater version number.

This method returns the requirements object.

=method add_maximum

  $req->add_maximum( $module => $version );

This adds a new maximum version requirement.  If the new requirement is
redundant to the existing specification, this has no effect.

Maximum requirements are inclusive.  No version strictly greater than the given
version is allowed.

This method returns the requirements object.

=method add_exclusion

  $req->add_exclusion( $module => $version );

This adds a new excluded version.  For example, you might use these three
method calls:

  $req->add_minimum( $module => '1.00' );
  $req->add_maximum( $module => '1.82' );

  $req->add_exclusion( $module => '1.75' );

Any version between 1.00 and 1.82 inclusive would be acceptable, except for
1.75.

This method returns the requirements object.

=method exact_version

  $req->exact_version( $module => $version );

This sets the version required for the given module to I<exactly> the given
version.  No other version would be considered acceptable.

This method returns the requirements object.

=cut

BEGIN {
  for my $type (qw(minimum maximum exclusion exact_version)) {
    my $method = "with_$type";
    my $to_add = $type eq 'exact_version' ? $type : "add_$type";

    my $code = sub {
      my ($self, $name, $version) = @_;

      $version = $self->_version_object( $version );

      $self->__modify_entry_for($name, $method, $version);

      return $self;
    };
    
    no strict 'refs';
    *$to_add = $code;
  }
}

=method add_requirements

  $req->add_requirements( $another_req_object );

This method adds all the requirements in the given CPAN::Meta::Requirements object
to the requirements object on which it was called.  If there are any conflicts,
an exception is thrown.

This method returns the requirements object.

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

=method accepts_module

  my $bool = $req->accepts_modules($module => $version);

Given an module and version, this method returns true if the version
specification for the module accepts the provided version.  In other words,
given:

  Module => '>= 1.00, < 2.00'

We will accept 1.00 and 1.75 but not 0.50 or 2.00.

For modules that do not appear in the requirements, this method will return
true.

=cut

sub accepts_module {
  my ($self, $module, $version) = @_;

  $version = $self->_version_object( $version );

  return 1 unless my $range = $self->__entry_for($module);
  return $range->_accepts($version);
}

=method clear_requirement

  $req->clear_requirement( $module );

This removes the requirement for a given module from the object.

This method returns the requirements object.

=cut

sub clear_requirement {
  my ($self, $module) = @_;

  return $self unless $self->__entry_for($module);

  Carp::confess("can't clear requirements on finalized requirements")
    if $self->is_finalized;

  delete $self->{requirements}{ $module };

  return $self;
}

=method required_modules

This method returns a list of all the modules for which requirements have been
specified.

=cut

sub requested_version {
	my ($self, $module) = @_;
	my $entry = $self->__entry_for($module);
	return $entry ? $entry->as_string : undef;
}

=method requested_version

  $req->requested_version( $module );

This returns the required version for a given module. This should be used for
informational purposes such as error message only and should not be
interpreted in any way.

=cut

sub required_modules { keys %{ $_[0]{requirements} } }

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

sub __entry_for     { $_[0]{requirements}{ $_[1] } }

sub __modify_entry_for {
  my ($self, $name, $method, $version) = @_;

  my $fin = $self->is_finalized;
  my $old = $self->__entry_for($name);

  Carp::confess("can't add new requirements to finalized requirements")
    if $fin and not $old;

  my $new = ($old || 'CPAN::Meta::Requirements::_Range::Range')
          ->$method($version);

  Carp::confess("can't modify finalized requirements")
    if $fin and $old->as_string ne $new->as_string;

  $self->{requirements}{ $name } = $new;
}

=method is_simple

This method returns true if and only if all requirements are inclusive minimums
-- that is, if their string expression is just the version number.

=cut

sub is_simple {
  my ($self) = @_;
  for my $module ($self->required_modules) {
    # XXX: This is a complete hack, but also entirely correct.
    return if $self->__entry_for($module)->as_string =~ /\s/;
  }

  return 1;
}

=method is_finalized

This method returns true if the requirements have been finalized by having the
C<finalize> method called on them.

=cut

sub is_finalized { $_[0]{finalized} }

=method finalize

This method marks the requirements finalized.  Subsequent attempts to change
the requirements will be fatal, I<if> they would result in a change.  If they
would not alter the requirements, they have no effect.

If a finalized set of requirements is cloned, the cloned requirements are not
also finalized.

=cut

sub finalize { $_[0]{finalized} = 1 }

=method as_string_hash

This returns a reference to a hash describing the requirements using the
strings in the F<META.yml> specification.

For example after the following program:

  my $req = CPAN::Meta::Requirements->new;

  $req->add_minimum('CPAN::Meta::Requirements' => 0.102);

  $req->add_minimum('Library::Foo' => 1.208);

  $req->add_maximum('Library::Foo' => 2.602);

  $req->add_minimum('Module::Bar'  => 'v1.2.3');

  $req->add_exclusion('Module::Bar'  => 'v1.2.8');

  $req->exact_version('Xyzzy'  => '6.01');

  my $hashref = $req->as_string_hash;

C<$hashref> would contain:

  {
    'CPAN::Meta::Requirements' => '0.102',
    'Library::Foo' => '>= 1.208, <= 2.206',
    'Module::Bar'  => '>= v1.2.3, != v1.2.8',
    'Xyzzy'        => '== 6.01',
  }

=cut

sub as_string_hash {
  my ($self) = @_;

  my %hash = map {; $_ => $self->{requirements}{$_}->as_string }
             $self->required_modules;

  return \%hash;
}

=method add_string_requirement

  $req->add_string_requirement('Library::Foo' => '>= 1.208, <= 2.206');

This method parses the passed in string and adds the appropriate requirement
for the given module.  It understands version ranges as described in the
L<CPAN::Meta::Spec/Version Ranges>. For example:

=over 4

=item 1.3

=item >= 1.3

=item <= 1.3

=item == 1.3

=item ! 1.3

=item > 1.3

=item < 1.3

=item >= 1.3, ! 1.5, <= 2.0

A version number without an operator is equivalent to specifying a minimum
(C<E<gt>=>).  Extra whitespace is allowed.

=back

=cut

my %methods_for_op = (
  '==' => [ qw(exact_version) ],
  '!=' => [ qw(add_exclusion) ],
  '>=' => [ qw(add_minimum)   ],
  '<=' => [ qw(add_maximum)   ],
  '>'  => [ qw(add_minimum add_exclusion) ],
  '<'  => [ qw(add_maximum add_exclusion) ],
);

sub add_string_requirement {
  my ($self, $module, $req) = @_;

  Carp::confess("No requirement string provided for $module")
    unless defined $req && length $req;

  my @parts = split qr{\s*,\s*}, $req;


  for my $part (@parts) {
    my ($op, $ver) = $part =~ m{\A\s*(==|>=|>|<=|<|!=)\s*(.*)\z};

    if (! defined $op) {
      $self->add_minimum($module => $part);
    } else {
      Carp::confess("illegal requirement string: $req")
        unless my $methods = $methods_for_op{ $op };

      $self->$_($module => $ver) for @$methods;
    }
  }
}

=method from_string_hash

  my $req = CPAN::Meta::Requirements->from_string_hash( \%hash );

This is an alternate constructor for a CPAN::Meta::Requirements object.  It takes
a hash of module names and version requirement strings and returns a new
CPAN::Meta::Requirements object.

=cut

sub from_string_hash {
  my ($class, $hash) = @_;

  my $self = $class->new;

  for my $module (keys %$hash) {
    my $req = $hash->{$module};
    unless ( defined $req && length $req ) {
      $req = 0;
      Carp::carp("Undefined requirement for $module treated as '0'");
    }
    $self->add_string_requirement($module, $req);
  }

  return $self;
}

##############################################################

{
  package
    CPAN::Meta::Requirements::_Range::Exact;
  sub _new     { bless { version => $_[1] } => $_[0] }

  sub _accepts { return $_[0]{version} == $_[1] }

  sub as_string { return "== $_[0]{version}" }

  sub as_modifiers { return [ [ exact_version => $_[0]{version} ] ] }

  sub _clone {
    (ref $_[0])->_new( version->new( $_[0]{version} ) )
  }

  sub with_exact_version {
    my ($self, $version) = @_;

    return $self->_clone if $self->_accepts($version);

    Carp::confess("illegal requirements: unequal exact version specified");
  }

  sub with_minimum {
    my ($self, $minimum) = @_;
    return $self->_clone if $self->{version} >= $minimum;
    Carp::confess("illegal requirements: minimum above exact specification");
  }

  sub with_maximum {
    my ($self, $maximum) = @_;
    return $self->_clone if $self->{version} <= $maximum;
    Carp::confess("illegal requirements: maximum below exact specification");
  }

  sub with_exclusion {
    my ($self, $exclusion) = @_;
    return $self->_clone unless $exclusion == $self->{version};
    Carp::confess("illegal requirements: excluded exact specification");
  }
}

##############################################################

{
  package
    CPAN::Meta::Requirements::_Range::Range;

  sub _self { ref($_[0]) ? $_[0] : (bless { } => $_[0]) }

  sub _clone {
    return (bless { } => $_[0]) unless ref $_[0];

    my ($s) = @_;
    my %guts = (
      (exists $s->{minimum} ? (minimum => version->new($s->{minimum})) : ()),
      (exists $s->{maximum} ? (maximum => version->new($s->{maximum})) : ()),

      (exists $s->{exclusions}
        ? (exclusions => [ map { version->new($_) } @{ $s->{exclusions} } ])
        : ()),
    );

    bless \%guts => ref($s);
  }

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

    my @exclusions = @{ $self->{exclusions} || [] };

    my @parts;

    for my $pair (
      [ qw( >= > minimum ) ],
      [ qw( <= < maximum ) ],
    ) {
      my ($op, $e_op, $k) = @$pair;
      if (exists $self->{$k}) {
        my @new_exclusions = grep { $_ != $self->{ $k } } @exclusions;
        if (@new_exclusions == @exclusions) {
          push @parts, "$op $self->{ $k }";
        } else {
          push @parts, "$e_op $self->{ $k }";
          @exclusions = @new_exclusions;
        }
      }
    }

    push @parts, map {; "!= $_" } @exclusions;

    return join q{, }, @parts;
  }

  sub with_exact_version {
    my ($self, $version) = @_;
    $self = $self->_clone;

    Carp::confess("illegal requirements: exact specification outside of range")
      unless $self->_accepts($version);

    return CPAN::Meta::Requirements::_Range::Exact->_new($version);
  }

  sub _simplify {
    my ($self) = @_;

    if (defined $self->{minimum} and defined $self->{maximum}) {
      if ($self->{minimum} == $self->{maximum}) {
        Carp::confess("illegal requirements: excluded all values")
          if grep { $_ == $self->{minimum} } @{ $self->{exclusions} || [] };

        return CPAN::Meta::Requirements::_Range::Exact->_new($self->{minimum})
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
    $self = $self->_clone;

    if (defined (my $old_min = $self->{minimum})) {
      $self->{minimum} = (sort { $b cmp $a } ($minimum, $old_min))[0];
    } else {
      $self->{minimum} = $minimum;
    }

    return $self->_simplify;
  }

  sub with_maximum {
    my ($self, $maximum) = @_;
    $self = $self->_clone;

    if (defined (my $old_max = $self->{maximum})) {
      $self->{maximum} = (sort { $a cmp $b } ($maximum, $old_max))[0];
    } else {
      $self->{maximum} = $maximum;
    }

    return $self->_simplify;
  }

  sub with_exclusion {
    my ($self, $exclusion) = @_;
    $self = $self->_clone;

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
