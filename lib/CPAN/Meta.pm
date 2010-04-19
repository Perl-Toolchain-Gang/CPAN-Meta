use 5.006;
use strict;
use warnings;
use autodie;
package CPAN::Meta;
# ABSTRACT: the distribution metadata for a CPAN dist

=head1 SYNOPSIS

  my $meta = CPAN::Meta->load('META.json');

  printf "testing requirements for %s version %s\n",
    $meta->name,
    $meta->version;

  my $prereqs = $meta->requirements_for('configure');

  for my $module ($prereqs->required_modules) {
    my $version = get_local_version($module);

    die "missing required module $module" unless defined $version;
    die "version for $module not in range"
      unless $prereqs->accepts_module($module, $version);
  }

=head1 DESCRIPTION

Software distributions released to the CPAN include a F<META.json> or, for
older distributions, F<META.yml>, which describes the distribution, its
contents, and the requirements for building and installing the distribution.
The data structure stored in the F<META.json> file is described in
L<CPAN::Meta::Spec>.

CPAN::Meta provides a simple class to represent this distribution metadata (or
I<distmeta>), along with some helpful methods for interrogating that data.

The documentation below is only for the methods of the CPAN::Meta object.  For
information on the meaning of individual fields, consult the spec.

=cut

use Carp qw(carp confess);
use CPAN::Meta::Feature;
use CPAN::Meta::Prereqs;
use CPAN::Meta::Converter;
use CPAN::Meta::Validator;
use JSON 2 ();
use Parse::CPAN::Meta ();

=head1 STRING DATA

The following methods return a single value, which is the value for the
corresponding entry in the distmeta structure.  Values should be either undef
or strings.

=for :list
* abstract
* description
* dynamic_config
* generated_by
* name
* release_status
* version

=cut

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

=head1 LIST DATA

These methods return lists of string values, which might be represented in the
distmeta structure as arrayrefs or scalars:

=for :list
* authors
* keywords
* licenses

The C<authors> and C<licenses> methods may also be called as C<author> and
C<license>, respectively, to match the field name in the distmeta structure.

=cut

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
      confess "$attr must be called in list context"
        unless wantarray;
      return @$value if ref $value;
      return $value;
    };
  }
}

sub authors  { $_[0]->author }
sub licenses { $_[0]->license }

=head1 MAP DATA

These readers return hashrefs of arbitrary unblessed data structures, each
described more fully in the specification:

=for :list
* meta_spec
* resources
* provides
* no_index
* prereqs
* optional_features

=cut

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

=method new

  my $meta = CPAN::Meta->new($distmeta_struct);

Returns a valid CPAN::Meta object or dies if the supplied hash reference
fails to validate.  Older format metadata will be up-converted to version 2
if if validates against the original stated specification.

For a more liberal treatment, manually upcovert older metadata versions
using L<CPAN::Meta::Converter> before calling C<new()>

=cut

sub _new {
  my ($class, $struct) = @_;

  # validate original struct
  my $cmv = CPAN::Meta::Validator->new( $struct );
  unless ( $cmv->is_valid) {
    die "Invalid metadata structure. Errors: "
      . join(", ", $cmv->errors) . "\n";
  }

  # upconvert to version 2
  my $cmc = CPAN::Meta::Converter->new( $struct );
  my $self = $cmc->convert( version => 2 );
  return bless $self => $class;
}

sub new {
  my ($class, $struct) = @_;
  my $self = eval { $class->_new($struct) };
  confess($@) if $@;
  return $self;
}

=method create

  my $meta = CPAN::Meta->create($distmeta_struct);

This is same as C<new()>, except that C<generated_by> and C<meta-spec> fields
will be generated if not provided.

=cut

sub create {
  my ($class, $struct) = @_;
  my $version = __PACKAGE__->VERSION || 2;
  $struct->{generated_by} ||= __PACKAGE__ . " version $version" ;
  $struct->{'meta-spec'}{version} ||= int($version);
  my $self = eval { $class->_new($struct) };
  confess($@) if $@;
  return $self;
}

=method load

  my $meta = CPAN::Meta->load($distmeta_file);

Given a pathname to a file containing metadata, this deserializes the file
according to its file suffix and constructs a new C<CPAN::Meta> object, just
like C<new()>.  It will die if the deserialized version fails to validate
against its stated specification version.

=cut

# XXX private to help tests conversion/validation -- dagolden, 2010-04-12
sub _load_file {
  my ($class, $file) = @_;

  my $struct;
  if ( $file =~ m{\.json} ) {
    my $guts = do { local (@ARGV,$/) = $file; <> };
    $struct = JSON->new->utf8->decode($guts);
  }
  elsif ( $file =~ m{\.ya?ml} ) {
    my @yaml = Parse::CPAN::Meta::LoadFile( $file );
    $struct = $yaml[0];
  }
  return $struct;
}

# XXX: Much of this can be simplified when we can rely on a JSON-speaking
# upstream Parse::CPAN::Meta. -- rjbs, 2010-04-12
sub load_file {
  my ($class, $file) = @_;

  # load
  confess "load() requires a valid, readable filename"
    unless -r $file;
  my $struct = $class->_load_file( $file )
    or confess "load() could not determine the filetype of '$file'";

  my $self = eval { $class->_new($struct) };
  confess($@) if $@;
  return $self;
}

=method load_yaml_string

  my $meta = CPAN::Meta->load_yaml_string($yaml);

This method returns a new CPAN::Meta object using the first document in the
given YAML string.  In other respects it is identical to C<load_file()>.

=cut

sub load_yaml_string {
  my ($class, $yaml) = @_;
  my ($struct) = Parse::CPAN::Meta::Load( $yaml );
  my $self = eval { $class->_new($struct) };
  confess($@) if $@;
  return $self;
}

=method load_json_string

  my $meta = CPAN::Meta->load_json_string($json);

This method returns a new CPAN::Meta object using the structure represented by
the given JSON string.  In other respects it is identical to C<load_file()>.

=cut

sub load_json_string {
  my ($class, $json) = @_;
  my $struct = JSON->new->utf8->decode($json);
  my $self = eval { $class->_new($struct) };
  confess($@) if $@;
  return $self;
}

=method save

  $meta->save($distmeta_file);

Serializes the object as JSON and writes it to the given file.  The filename
should end in '.json'.

=cut

sub save {
  my ($self, $file) = @_;

  carp "'$file' should end in '.json'"
    unless $file =~ m{\.json$};

  open my $fh, ">", $file;
  print {$fh} JSON->new->utf8->pretty->encode({%$self});
}

=method meta_spec_version

This method returns the version part of the C<meta_spec> entry in the distmeta
structure.  It is equivalent to:

  $meta->meta_spec->{version};

=cut

# XXX Do we need this if we always upconvert? -- dagolden, 2010-04-14
sub meta_spec_version {
  my ($self) = @_;
  return $self->meta_spec->{version};
}

=method effective_prereqs

  my $prereqs = $meta->effective_prereqs;

  my $prereqs = $meta->effective_prereqs( \@feature_identifiers );

This method returns a L<CPAN::Meta::Prereqs> object describing all the
prereqs for the distribution.  If an arrayref of feature identifiers is given,
the prereqs for the identified features are merged together with the
distribution's core prereqs before the CPAN::Meta::Prereqs object is returned.

=cut

sub effective_prereqs {
  my ($self, $features) = @_;
  $features ||= [];

  my $prereq = CPAN::Meta::Prereqs->new($self->prereqs);

  return $prereq unless @$features;

  my @other = map {; $self->feature($_)->prereqs } @$features;

  return $prereq->with_merged_prereqs(\@other);
}

=method should_index_file

  ... if $meta->should_index_file( $filename );

This method returns true if the given file should be indexed.  It decides this
by checking the C<file> and C<directory> keys in the C<no_index> property of
the distmeta structure.

C<$filename> should be given in unix format.

=cut

sub should_index_file {
  my ($self, $filename) = @_;

  for my $no_index_file (@{ $self->no_index->{file} || [] }) {
    return if $filename eq $no_index_file;
  }

  for my $no_index_dir (@{ $self->no_index->{directory} }) {
    $no_index_dir =~ s{$}{/} unless $no_index_dir =~ m{/\z};
    return if index($filename, $no_index_dir) == 0;
  }

  return 1;
}

=method should_index_package

  ... if $meta->should_index_package( $package );

This method returns true if the given package should be indexed.  It decides
this by checking the C<package> and C<namespace> keys in the C<no_index>
property of the distmeta structure.

=cut

sub should_index_package {
  my ($self, $package) = @_;

  for my $no_index_pkg (@{ $self->no_index->{package} || [] }) {
    return if $package eq $no_index_pkg;
  }

  for my $no_index_ns (@{ $self->no_index->{namespace} }) {
    return if index($package, "${no_index_ns}::") == 0;
  }

  return 1;
}

=method features

  my @feature_objects = $meta->features;

This method returns a list of L<CPAN::Meta::Feature> objects, one for each
optional feature described by the distribution's metadata.

=cut

sub features {
  my ($self) = @_;

  my $opt_f = $self->optional_features;
  my @features = map {; CPAN::Meta::Feature->new($_ => $opt_f->{ $_ }) }
                 keys %$opt_f;

  return @features;
}

=method feature

  my $feature_object = $meta->feature( $identifier );

This method returns a L<CPAN::Meta::Feature> object for the optional feature
with the given identifier.  If no feature with that identifier exists, an
exception will be raised.

=cut

sub feature {
  my ($self, $ident) = @_;

  confess "no feature named $ident"
    unless my $f = $self->optional_features->{ $ident };

  return CPAN::Meta::Feature->new($ident, $f);
}

1;

__END__

=head1 BUGS

Please report any bugs or feature using the CPAN Request Tracker.
Bugs can be submitted through the web interface at
L<http://rt.cpan.org/Dist/Display.html?Queue=CPAN-Meta>

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

=head1 SEE ALSO

=for :list
* L<CPAN::Meta::Converter>
* L<CPAN::Meta::Validator>

=cut

