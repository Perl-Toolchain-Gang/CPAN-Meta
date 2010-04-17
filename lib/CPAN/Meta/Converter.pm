use 5.006;
use strict;
use warnings;
use autodie;
package CPAN::Meta::Converter;
# ABSTRACT: Convert CPAN distribution metadata structures

=head1 SYNOPSIS

  my $struct = decode_json_file('META.json');

  my $cmc = CPAN::Meta::Converter->new( $struct );

  my $new_struct = $cmc->convert( version => "2" );

=head1 DESCRIPTION

This module converts CPAN Meta structures from one form to another.  The
primary use is to convert older structures to the most modern version of
the specification, but other transformations may be implemented in the
future as needed.  (E.g. stripping all custom fields or stripping all
optional fields.)

=cut

use Carp qw(carp confess croak);
use CPAN::Meta::Validator;

my %known_specs = (
    '2'   => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
    '1.4' => 'http://module-build.sourceforge.net/META-spec-v1.4.html',
    '1.3' => 'http://module-build.sourceforge.net/META-spec-v1.3.html',
    '1.2' => 'http://module-build.sourceforge.net/META-spec-v1.2.html',
    '1.1' => 'http://module-build.sourceforge.net/META-spec-v1.1.html',
    '1.0' => 'http://module-build.sourceforge.net/META-spec-v1.0.html'
);

my @spec_list = sort { $a <=> $b } keys %known_specs;
my ($LOWEST, $HIGHEST) = @spec_list[0,-1];

#--------------------------------------------------------------------------#
# converters
#
# called as $converter->($element, $field_name, $full_meta, $to_version)
#
# defined return value used for field
# undef return value means field is skipped
#--------------------------------------------------------------------------#

sub _keep { $_[0] }

sub _keep_or_one { defined($_[0]) ? $_[0] : 1 }

sub _keep_or_zero { defined($_[0]) ? $_[0] : 0 }

sub _keep_or_unknown { defined($_[0]) ? $_[0] : "unknown" }

sub _generated_by { __PACKAGE__ . " version " . (__PACKAGE__->VERSION || "<dev>") }

sub _listify { ! defined $_[0] ? undef : ref $_[0] eq 'ARRAY' ? $_[0] : [$_[0]] }

sub _prefix_custom { "x_" . $_[0] }

sub _change_meta_spec {
  my ($element, undef, undef, $version) = @_;
  $element->{version} = $version;
  $element->{url} = $known_specs{$version};
  return $element;
}

my @valid_licenses_1 = (
  'perl',
  'gpl',
  'apache',
  'artistic',
  'artistic2',
  'artistic-2.0',
  'lgpl',
  'bsd',
  'gpl',
  'mit',
  'mozilla',
  'open_source',
  'unrestricted',
  'restrictive',
  'unknown',
);

my %license_map_1 = ( map { $_ => 1 } @valid_licenses_1 );

sub _license_1 {
  my ($element) = @_;
  return 'unknown' unless defined $element;
  if ( $license_map_1{lc $element} ) {
    return lc $element;
  }
  return 'unknown';
}

my @valid_licenses_2 = qw(
  agpl_3
  apache_1_1
  apache_2_0
  artistic_1
  artistic_2
  bsd
  freebsd
  gfdl_1_2
  gfdl_1_3
  gpl_1
  gpl_2
  gpl_3
  lgpl_2_1
  lgpl_3_0
  mit
  mozilla_1_0
  mozilla_1_1
  openssl
  perl_5
  qpl_1_0
  ssleay
  sun
  zlib
  open_source
  restricted
  unrestricted
  unknown
);

my %license_map_2 = (
  ( map { $_ => $_ } @valid_licenses_2 ),
  apache => 'apache_2_0',
  artistic => 'artistic_1',
  gpl => 'gpl_1',
  lgpl => 'lgpl_2_1',
  mozilla => 'mozilla_1_0',
  perl => 'perl_5',
);

sub _license_2 {
  my ($element) = @_;
  return [ 'unknown' ] unless defined $element;
  $element = [ $element ] unless ref $element eq 'ARRAY';
  my @new_list;
  for my $lic ( @$element ) {
    next unless defined $lic;
    if ( my $new = $license_map_2{lc $lic} ) {
      push @new_list, $new;
    }
  }
  return @new_list ? \@new_list : [ 'unknown' ];
}

my $no_index_spec_1_2 = {
  'file' => \&_listify,
  'dir' => \&_listify,
  'package' => \&_listify,
  'namespace' => \&_listify,
};

my $no_index_spec_1_3 = {
  'file' => \&_listify,
  'directory' => \&_listify,
  'package' => \&_listify,
  'namespace' => \&_listify,
};

sub _no_index_1_2 {
  my (undef, undef, $meta) = @_;
  return _convert($meta->{private}, $no_index_spec_1_2);
}

sub _no_index_directory {
  my ($element) = @_;
  return unless $element;
  if ( exists $element->{dir} ) {
    $element->{directory} = delete $element->{dir};
  }
  return _convert($element, $no_index_spec_1_3);
}

sub _version_map {
  my ($element) = @_;
  return undef unless defined $element;
  return $element unless ref $element eq 'HASH';
  my $new_map = {};
  for my $k ( keys %$element ) {
    my $value = $element->{$k};
    $new_map->{$k} = (defined $value && length $value) ? $value : 0;
  }
  return $new_map;
}

sub _prereqs {
  my (undef, undef, $meta) = @_;
  my $prereqs = {};
  for my $phase ( qw/build configure/ ) {
    my $key = "${phase}_requires";
    $prereqs->{$phase}{requires} = _version_map($meta->{$key})
      if $meta->{$key};
  }
  for my $rel ( qw/requires recommends conflicts/ ) {
    $prereqs->{runtime}{$rel} = _version_map($meta->{$rel})
      if $meta->{$rel};
  }
  return $prereqs;
}

sub _optional_features_2 {
  my (undef, undef, $meta) = @_;
  return undef unless exists $meta->{optional_features};
  my $origin = $meta->{optional_features};
  my $features = {};
  for my $name ( keys %$origin ) {
    $features->{$name} = {
      description => $origin->{$name}{description},
      prereqs => _prereqs(undef, undef, $origin->{$name}),
    };
    delete $features->{$name}{prereqs}{configure};
  }
  return $features;
}

sub _optional_features_1_4 {
  my ($element) = @_;
  return unless $element;
  for my $drop ( qw/requires_packages requires_os excluded_os/ ) {
    delete $element->{$drop};
  }
  return $element;
}

#  resources => {
#    license     => [ 'http://dev.perl.org/licenses/' ],
#    homepage    => 'http://sourceforge.net/projects/module-build',
#    bugtracker  => {
#      web    => 'http://github.com/dagolden/cpan-meta-spec/issues',
#      mailto => 'meta-bugs@example.com',
#    },
#    repository  => {
#      url  => 'git://github.com/dagolden/cpan-meta-spec.git',
#      web  => 'http://github.com/dagolden/cpan-meta-spec',
#      type => 'git',
#    },

my $resource2_spec = {
  license    => \&_listify,
  homepage   => \&_keep,
  bugtracker => sub { return $_[0] ? { web => $_[0] } : undef },
  repository => sub { return $_[0] ? { web => $_[0] } : undef },
  ':custom'  => \&_prefix_custom,
};

sub _resources_2 {
  my (undef, undef, $meta, $version) = @_;
  return undef unless exists $meta->{resources};
  return _convert($meta->{resources}, $resource2_spec);
}

my $resource1_spec = {
  license    => \&_keep,
  homepage   => \&_keep,
  bugtracker => \&_keep,
  repository => \&_keep,
  ':custom'  => \&_keep,
};

sub _resources_1_3 {
  my (undef, undef, $meta, $version) = @_;
  return undef unless exists $meta->{resources};
  return _convert($meta->{resources}, $resource1_spec);
}

*_resources_1_4 = *_resources_1_3;

sub _resources_1_2 {
  my (undef, undef, $meta) = @_;
  return undef unless exists $meta->{license_url};
  return { license => $meta->{license_url} };
}

sub _release_status {
  my (undef, undef, $meta) = @_;
  my $version = $meta->{version} || '';
  return ( $version =~ /_/ ) ? 'testing' : 'stable';
}

sub _convert {
  my ($data, $spec, $to_version) = @_;

  my $new_data = {};
  for my $key ( %$spec ) {
    next if $key eq ':custom' || $key eq ':drop';
    next unless my $fcn = $spec->{$key};
    die "spec for '$key' is not a coderef"
      unless ref $fcn && ref $fcn eq 'CODE';
    my $new_value = $fcn->($data->{$key}, $key, $data, $to_version);
    $new_data->{$key} = $new_value if defined $new_value;
  }

  my $drop_list   = $spec->{':drop'};
  my $customizer  = $spec->{':custom'} || \&_keep;

  for my $key ( keys %$data ) {
    next if $drop_list && grep { $key eq $_ } @$drop_list;
    next if $spec->{$key}; # we handled it
    $new_data->{ $customizer->($key) } = $data->{$key};
  }

  return $new_data;
}

#--------------------------------------------------------------------------#
# define converters for each conversion
#--------------------------------------------------------------------------#

# each converts from prior version
# special ":custom" field is used for keys not recognized in spec
my %up_convert = (
  '2-from-1.4' => {
    # PRIOR MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_2,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep_or_unknown,
    'version'             => \&_keep_or_zero,
    # CHANGED TO MANDATORY
    'dynamic_config'      => \&_keep_or_one,
    # ADDED MANDATORY
    'release_status'      => \&_release_status,
    # PRIOR OPTIONAL
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_optional_features_2,
    'provides'            => \&_keep,
    'resources'           => \&_resources_2,
    # ADDED OPTIONAL
    'description'         => \&_keep,
    'prereqs'             => \&_prereqs,

    # drop these deprecated fields, but only after we convert
    ':drop' => [ qw(
        build_requires
        configure_requires
        conflicts
        distribution_type
        license_url
        private
        recommends
        requires
    ) ],

    # other random keys need x_ prefixing
    ':custom'              => \&_prefix_custom,
  },
  '1.4-from-1.3' => {
    # PRIOR MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep_or_unknown,
    'version'             => \&_keep_or_zero,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_optional_features_1_4,
    'provides'            => \&_keep,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    'resources'           => \&_resources_1_4,
    # ADDED OPTIONAL
    'configure_requires'  => \&_keep,

    # drop these deprecated fields, but only after we convert
    ':drop' => [ qw(
      license_url
      private
    )],

    # other random keys are OK if already valid
    ':custom'              => \&_keep
  },
  '1.3-from-1.2' => {
    # PRIOR MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep_or_unknown,
    'version'             => \&_keep_or_zero,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_keep,
    'provides'            => \&_keep,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    'resources'           => \&_resources_1_3,

    # drop these deprecated fields, but only after we convert
    ':drop' => [ qw(
      license_url
      private
    )],

    # other random keys are OK if already valid
    ':custom'              => \&_keep
  },
  '1.2-from-1.1' => {
    # PRIOR MANDATORY
    'version'             => \&_keep_or_zero,
    # CHANGED TO MANDATORY
    'license'             => \&_license_1,
    'name'                => \&_keep_or_unknown,
    'generated_by'        => \&_generated_by,
    # ADDED MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'meta-spec'           => \&_change_meta_spec,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    # ADDED OPTIONAL
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_1_2,
    'optional_features'   => \&_keep,
    'provides'            => \&_keep,
    'resources'           => \&_resources_1_2,

    # drop these deprecated fields, but only after we convert
    ':drop' => [ qw(
      license_url
      private
    )],

    # other random keys are OK if already valid
    ':custom'              => \&_keep
  },
  '1.1-from-1.0' => {
    # CHANGED TO MANDATORY
    'version'             => \&_keep_or_zero,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'name'                => \&_keep,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    # ADDED OPTIONAL
    'license_url'         => \&_keep,
    'private'             => \&_keep,

    # other random keys are OK if already valid
    ':custom'              => \&_keep
  },
);

#--------------------------------------------------------------------------#
# Code
#--------------------------------------------------------------------------#

=method new

  my $cmc = CPAN::Meta::Converter->new( $struct );

The constructor must be passed a B<valid> metadata structure.

=cut

sub new {
  my ($class,$data) = @_;

  # create an attributes hash
  my $self = {
    'data'    => $data,
    'spec'    => $data->{'meta-spec'}{'version'} || "1.0",
  };

  # create the object
  return bless $self, $class;
}

=method convert

  my $new_struct = $cmc->convert( version => "2" );

Returns a new hash reference with the metadata converted to a
different form.

Valid parameters include:

=head3 version

Currently, only upconverting older versions is supported.  Converting a
file to its own version will standardize the format. For exmaple, if
C<author> is given as a scalar, it will converted to an array reference
containing the item.

=cut

sub convert {
  my ($self, %args) = @_;
  my $args = { %args };

  my $new_version = $args->{version} || $HIGHEST;

  my ($old_version) = $self->{spec};

  if ( $old_version == $new_version ) {
    return { %{$self->{data}} }
  }
  elsif ( $old_version > $new_version )  {
    die "downconverting not yet supported";
  }
  else {
    my @vers = sort { $a <=> $b } keys %known_specs;
    my $converted = { %{$self->{data}} };
    for my $i ( 0 .. $#vers-1 ) {
      next if $vers[$i] < $old_version;
      my $spec_string = "$vers[$i+1]-from-$vers[$i]";
      $converted = _convert( $converted, $up_convert{$spec_string}, $vers[$i+1] );
      my $cmv = CPAN::Meta::Validator->new( $converted );
      unless ( $cmv->is_valid ) {
        my $errs = join("\n", $cmv->errors);
        croak "Failed to upconvert metadata to $vers[$i+1]. Errors:\n$errs\n";
      }
    }
    return $converted;
  }
}

1;
