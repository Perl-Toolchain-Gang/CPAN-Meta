use strict;
use warnings;
package CPAN::Meta::Feature;
# ABSTRACT: an optional feature provided by a CPAN distribution

use CPAN::Meta::Prereqs;

=head1 DESCRIPTION

A CPAN::Meta::Feature object describes an optional feature offered by a CPAN
distribution and specified in the distribution's F<META.json> (or F<META.yml>)
file.

For the most part, this class will only be used when operating on the result of
the C<feature> or C<features> methods on a L<CPAN::Meta> object.

=method new

  my $feature = CPAN::Meta::Feature->new( $identifier => \%spec );

This returns a new Feature object.  The C<%spec> argument to the constructor
should be the same as the value of the C<optional_feature> entry in the
distmeta.  It must contain entries for C<description> and C<prereqs>.

=cut

sub new {
  my ($class, $identifier, $spec) = @_;

  my %guts = (
    identifier  => $identifier,
    description => $spec->{description},
    prereqs     => CPAN::Meta::Prereqs->new($spec->{prereqs}),
  );

  bless \%guts => $class;
}

=method identifier

This method returns the feature's identifier.

=cut

sub identifier  { $_[0]{identifier}  }

=method description

This method returns the feature's long description.

=cut

sub description { $_[0]{description} }

=method prereqs

This method returns the feature's prerequisites as a L<CPAN::Meta::Prereqs>
object.

=cut

sub prereqs     { $_[0]{prereqs} }

1;
