use 5.006;
use strict;
use warnings;
use autodie;
package CPAN::Meta;
# ABSTRACT: the distribution metadata for a CPAN dist

=head1 SYNOPSIS

  my $meta = CPAN::Meta->load_file('META.json');

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

use Carp qw(carp croak);
use CPAN::Meta::Feature;
use CPAN::Meta::Prereqs;
use CPAN::Meta::Converter;
use CPAN::Meta::Validator;
use Module::Load::Conditional qw(can_load);
use Storable ();

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
      croak "$attr must be called in list context"
        unless wantarray;
      return @{ Storable::dclone($value) } if ref $value;
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
      return Storable::dclone($value) if $value;
      return {};
    };
  }
}

=head1 CUSTOM DATA

A list of custom keys are available from the C<custom_keys> method and
particular keys may be retrieved with the C<custom> method.

  say $meta->custom($_) for $meta->custom_keys;

If a custom key refers to a data structure, a deep clone is returned.

=cut

sub custom_keys {
  return grep { /^x_/i } keys %{$_[0]};
}

sub custom {
  my ($self, $attr) = @_;
  my $value = $self->{$attr};
  return Storable::dclone($value) if ref $value;
  return $value;
}

=method new

  my $meta = CPAN::Meta->new($distmeta_struct, \%options);

Returns a valid CPAN::Meta object or dies if the supplied metadata hash
reference fails to validate.  Older-format metadata will be up-converted to
version 2 if they validate against the original stated specification.

Valid options include:

=over

=item *

lazy_validation -- if true, new will attempt to convert the given metadata
to version 2 before attempting to validate it.  This means than any
fixable errors will be handled by CPAN::Meta::Converter before validation.
(Note that this might result in invalid optional data being silently
dropped.)  The default is false.

=back

=cut

sub _new {
  my ($class, $struct, $options) = @_;
  my $self;

  if ( $options->{lazy_validation} ) {
    # try to convert to a valid structure; if succeeds, then return it
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $self = $cmc->convert( version => 2 ); # valid or dies
    return bless $self, $class;
  }
  else {
    # validate original struct
    my $cmv = CPAN::Meta::Validator->new( $struct );
    unless ( $cmv->is_valid) {
      die "Invalid metadata structure. Errors: "
        . join(", ", $cmv->errors) . "\n";
    }
  }

  # up-convert older spec versions
  my $version = $struct->{'meta-spec'}{version} || '1.0';
  if ( $version == 2 ) {
    $self = $struct;
  }
  else {
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $self = $cmc->convert( version => 2 );
  }

  return bless $self, $class;
}

sub new {
  my ($class, $struct, $options) = @_;
  my $self = eval { $class->_new($struct, $options) };
  croak($@) if $@;
  return $self;
}

=method create

  my $meta = CPAN::Meta->create($distmeta_struct);

This is same as C<new()>, except that C<generated_by> and C<meta-spec> fields
will be generated if not provided.  This means the metadata structure is
assumed to otherwise follow the latest L<CPAN::Meta::Spec>.

=cut

sub create {
  my ($class, $struct, $options) = @_;
  my $version = __PACKAGE__->VERSION || 2;
  $struct->{generated_by} ||= __PACKAGE__ . " version $version" ;
  $struct->{'meta-spec'}{version} ||= int($version);
  my $self = eval { $class->_new($struct, $options) };
  croak ($@) if $@;
  return $self;
}

=method load_file

  my $meta = CPAN::Meta->load_file($distmeta_file, \%options);

Given a pathname to a file containing metadata, this deserializes the file
according to its file suffix and constructs a new C<CPAN::Meta> object, just
like C<new()>.  It will die if the deserialized version fails to validate
against its stated specification version.

It takes the same options as C<new()> but C<lazy_validation> defaults to
true.

=cut

sub load_file {
  my ($class, $file, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  local $Module::Load::Conditional::CHECK_INC_HASH = 1;
  can_load( modules => { 'Parse::CPAN::Meta' => 1.4200 } )
    or croak "CPAN::Meta requires Parse::CPAN::Meta 1.4200 or later\n";

  croak "load_file() requires a valid, readable filename"
    unless -r $file;

  my $self;
  eval {
    my $struct = Parse::CPAN::Meta->load_file( $file );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}

=method load_yaml_string

  my $meta = CPAN::Meta->load_yaml_string($yaml, \%options);

This method returns a new CPAN::Meta object using the first document in the
given YAML string.  In other respects it is identical to C<load_file()>.

=cut

sub load_yaml_string {
  my ($class, $yaml, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  my $self;
  eval {
    my ($struct) = Parse::CPAN::Meta->load_yaml_string( $yaml );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}

=method load_json_string

  my $meta = CPAN::Meta->load_json_string($json, \%options);

This method returns a new CPAN::Meta object using the structure represented by
the given JSON string.  In other respects it is identical to C<load_file()>.

=cut

sub load_json_string {
  my ($class, $json, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  my $self;
  eval {
    my $struct = Parse::CPAN::Meta->load_json_string( $json );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}

=method save

  $meta->save($distmeta_file, \%options);

Serializes the object as JSON and writes it to the given file.  The only valid
option is C<version>, which defaults to '2'.

For C<version> 2 (or higher), the filename should end in '.json'.  L<JSON::PP>
is the default JSON backend. Using another JSON backend requires L<JSON> 2.5 or
later and you must set the C<$ENV{PERL_JSON_BACKEND}> to a supported alternate
backend like L<JSON::XS>.

For C<version> less than 2, the filename should end in '.yml'.
L<CPAN::Meta::Converter> is used to generate an older metadata structure, which
is serialized to YAML.  CPAN::Meta::YAML is the default YAML backend.  You may
set the C<$ENV{PERL_YAML_BACKEND}> to a supported alternative backend, though
this is not recommended due to subtle incompatibilities between YAML parsers
on CPAN.

=cut

sub save {
  my ($self, $file, $options) = @_;

  my $version = $options->{version} || '2';

  my $struct;
  if ( $self->version ne $version ) {
    my $cmc = CPAN::Meta::Converter->new( $self->as_struct );
    $struct = $cmc->convert( version => $version );
  }
  else {
    $struct = $self->as_struct;
  }

  my $data;
  if ( $version ge '2' ) {
    carp "'$file' should end in '.json'"
      unless $file =~ m{\.json$};
    $data = _choose_json_backend()->new->utf8->pretty->encode($struct);
  }
  else {
    carp "'$file' should end in '.yml'"
      unless $file =~ m{\.yml$};
    my $backend = _choose_yaml_backend();
    $data = eval { no strict 'refs'; &{"$backend\::Dump"}($struct) };
    if ( $@ ) {
      croak $backend->can('errstr') ? $backend->errstr : $@
    }
  }

  open my $fh, ">", $file;
  print {$fh} $data;
  close $fh;
}

# Copied from Parse::CPAN::Meta
sub _choose_json_backend {
  local $Module::Load::Conditional::CHECK_INC_HASH = 1;
  if (! $ENV{PERL_JSON_BACKEND} or $ENV{PERL_JSON_BACKEND} eq 'JSON::PP') {
    can_load( modules => {'JSON::PP' => 2.27103}, verbose => 0 )
      or croak "JSON::PP 2.27103 is not available\n";
    return 'JSON::PP';
  }
  else {
    can_load( modules => {'JSON' => 2.5}, verbose => 0 )
      or croak  "JSON 2.5 is required for " .
                "\$ENV{PERL_JSON_BACKEND} = '$ENV{PERL_JSON_BACKEND}'\n";
    return "JSON";
  }
}

sub _choose_yaml_backend {
  local $Module::Load::Conditional::CHECK_INC_HASH = 1;
  if (! defined $ENV{PERL_YAML_BACKEND} ) {
    can_load( modules => {'CPAN::Meta::YAML' => 0.002}, verbose => 0 )
      or croak "CPAN::Meta::YAML 0.002 is not available\n";
    return "CPAN::Meta::YAML";
  }
  else {
    my $backend = $ENV{PERL_YAML_BACKEND};
    can_load( modules => {$backend => undef}, verbose => 0 )
      or croak "Could not load PERL_YAML_BACKEND '$backend'\n";
    $backend->can("Dump")
      or croak "PERL_YAML_BACKEND '$backend' does not implement Dump()\n";
    return $backend;
  }
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

  croak "no feature named $ident"
    unless my $f = $self->optional_features->{ $ident };

  return CPAN::Meta::Feature->new($ident, $f);
}

=method as_struct

  my $copy = $meta->as_struct;

This method returns a deep copy of the object's metadata as an unblessed has
reference.  This is useful for raw analysis or for passing to a converter
object.  For example:

  my $cmc = CPAN::Meta::Converter->new( $meta->as_struct );
  my $meta_1_4 = $cmc->convert( version => "1.4" );

=cut

sub as_struct {
  my ($self) = @_;
  my $json = _choose_json_backend();
  return $json->new->decode( $json->new->convert_blessed->encode( $self ) )
}

# Used by JSON::PP, etc. for "convert_blessed"
sub TO_JSON {
  return { %{ $_[0] } };
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

