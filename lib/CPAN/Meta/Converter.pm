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

use CPAN::Meta::Validator;
use Storable qw/dclone/;

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

sub _generated_by {
  my $gen = shift;
  my $sig = __PACKAGE__ . " version " . (__PACKAGE__->VERSION || "<dev>");

  return $sig unless defined $gen and length $gen;
  return $gen if $gen =~ /(, )\Q$sig/;
  return "$gen, $sig";
}

sub _listify { ! defined $_[0] ? undef : ref $_[0] eq 'ARRAY' ? $_[0] : [$_[0]] }

sub _prefix_custom {
  my $key = shift;
  $key =~ s/^(?!x_)   # Unless it already starts with x_
             (?:x-?)? # Remove leading x- or x (if present)
           /x_/ix;    # and prepend x_
  return $key;
}

sub _ucfirst_custom {
  my $key = shift;
  $key = ucfirst $key unless $key =~ /[A-Z]/;
  return $key;
}

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

my %license_downgrade_map = qw(
  agpl_3            open_source
  apache_1_1        apache
  apache_2_0        apache
  artistic_1        artistic
  artistic_2        artistic2
  bsd               bsd
  freebsd           open_source
  gfdl_1_2          open_source
  gfdl_1_3          open_source
  gpl_1             gpl
  gpl_2             gpl
  gpl_3             gpl
  lgpl_2_1          lgpl
  lgpl_3_0          lgpl
  mit               mit
  mozilla_1_0       mozilla
  mozilla_1_1       mozilla
  openssl           open_source
  perl_5            perl
  qpl_1_0           open_source
  ssleay            open_source
  sun               open_source
  zlib              open_source
  open_source       open_source
  restricted        restricted
  unrestricted      unrestricted
  unknown           unknown
);

sub _downgrade_license {
  my ($element) = @_;
  if ( ! defined $element ) {
    return "unknown";
  }
  elsif( ref $element eq 'ARRAY' ) {
    if ( @$element == 1 ) {
      return $license_downgrade_map{$element->[0]};
    }
    else {
      return 'unknown';
    }
  }
  elsif ( ! ref $element ) {
    return $license_downgrade_map{$element};
  }
  else {
    return "unknown";
  }
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
  my $no_index = $meta->{no_index} || $meta->{private};
  return _convert($no_index, $no_index_spec_1_2);
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

sub _prereqs_from_1 {
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

my $prereqs_spec = {
  configure => \&_prereqs_rel,
  build     => \&_prereqs_rel,
  test      => \&_prereqs_rel,
  runtime   => \&_prereqs_rel,
  develop   => \&_prereqs_rel,
  ':custom'  => \&_prefix_custom,
};

my $relation_spec = {
  requires   => \&_version_map,
  recommends => \&_version_map,
  suggests   => \&_version_map,
  conflicts  => \&_version_map,
  ':custom'  => \&_prefix_custom,
};

sub _cleanup_prereqs {
  my ($prereqs, $key, $meta, $to_version) = @_;
  return unless $prereqs && ref $prereqs eq 'HASH';
  return _convert( $prereqs, $prereqs_spec, $to_version );
}

sub _prereqs_rel {
  my ($relation, $key, $meta, $to_version) = @_;
  return unless $relation && ref $relation eq 'HASH';
  return _convert( $relation, $relation_spec, $to_version );
}


BEGIN {
  my @old_prereqs = qw(
    requires
    configure_requires
    recommends
    conflicts
  );

  for ( @old_prereqs ) {
    my $sub = "_get_$_";
    my ($phase,$type) = split qr/_/, $_;
    if ( ! defined $type ) {
      $type = $phase;
      $phase = 'runtime';
    }
    no strict 'refs';
    *{$sub} = sub { _extract_prereqs($_[2]->{prereqs},$phase,$type) };
  }
}

sub _get_build_requires {
  my ($data, $key, $meta) = @_;

  my $test_h  = _extract_prereqs($_[2]->{prereqs}, qw(test  requires)) || {};
  my $build_h = _extract_prereqs($_[2]->{prereqs}, qw(build requires)) || {};

  require Version::Requirements;
  my $test_req  = Version::Requirements->from_string_hash($test_h);
  my $build_req = Version::Requirements->from_string_hash($build_h);

  $test_req->add_requirements($build_req)->as_string_hash;
}

sub _extract_prereqs {
  my ($prereqs, $phase, $type) = @_;
  return unless ref $prereqs eq 'HASH';
  return $prereqs->{$phase}{$type};
}

sub _downgrade_optional_features {
  my (undef, undef, $meta) = @_;
  return undef unless exists $meta->{optional_features};
  my $origin = $meta->{optional_features};
  my $features = {};
  for my $name ( keys %$origin ) {
    $features->{$name} = {
      description => $origin->{$name}{description},
      requires => _extract_prereqs($origin->{$name}{prereqs},'runtime','requires'),
      configure_requires => _extract_prereqs($origin->{$name}{prereqs},'runtime','configure_requires'),
      build_requires => _extract_prereqs($origin->{$name}{prereqs},'runtime','build_requires'),
      recommends => _extract_prereqs($origin->{$name}{prereqs},'runtime','recommends'),
      conflicts => _extract_prereqs($origin->{$name}{prereqs},'runtime','conflicts'),
    };
    for my $k (keys %{$features->{$name}} ) {
      delete $features->{$name}{$k} unless defined $features->{$name}{$k};
    }
  }
  return $features;
}

sub _upgrade_optional_features {
  my (undef, undef, $meta) = @_;
  return undef unless exists $meta->{optional_features};
  my $origin = $meta->{optional_features};
  my $features = {};
  for my $name ( keys %$origin ) {
    $features->{$name} = {
      description => $origin->{$name}{description},
      prereqs => _prereqs_from_1(undef, undef, $origin->{$name}),
    };
    delete $features->{$name}{prereqs}{configure};
  }
  return $features;
}

my $optional_features_2_spec = {
  description => \&_keep_or_unknown,
  prereqs => \&_cleanup_prereqs,
  ':custom'  => \&_keep,
};

sub _feature_2 {
  my ($element, $key, $meta, $to_version) = @_;
  return unless $element && ref $element eq 'HASH';
  _convert( $element, $optional_features_2_spec, $to_version );
}

sub _cleanup_optional_features_2 {
  my ($element, $key, $meta, $to_version) = @_;
  return unless $element && ref $element eq 'HASH';
  my $new_data = {};
  for my $k ( keys %$element ) {
    $new_data->{$k} = _feature_2( $element->{$k}, $k, $meta, $to_version );
  }
  return unless keys %$new_data;
  return $new_data;
}

sub _optional_features_1_4 {
  my ($element) = @_;
  return unless $element;
  $element = _optional_features_as_map($element);
  for my $name ( keys %$element ) {
    for my $drop ( qw/requires_packages requires_os excluded_os/ ) {
      delete $element->{$name}{$drop};
    }
  }
  return $element;
}

sub _optional_features_as_map {
  my ($element) = @_;
  return unless $element;
  if ( ref $element eq 'ARRAY' ) {
    my %map;
    for my $feature ( @$element ) {
      my (@parts) = %$feature;
      $map{$parts[0]} = $parts[1];
    }
    $element = \%map;
  }
  return $element;
}

sub _is_urlish { defined $_[0] && $_[0] =~ m{\A[-+.a-z0-9]+:.+}i }

sub _url_or_drop {
  my ($element) = @_;
  return $element if _is_urlish($element);
  return;
}

sub _url_list {
  my ($element) = @_;
  return unless $element;
  $element = _listify( $element );
  $element = [ grep { _is_urlish($_) } @$element ];
  return unless @$element;
  return $element;
}

my $resource2_upgrade = {
  license    => sub { return _is_urlish($_[0]) ? _listify( $_[0] ) : undef },
  homepage   => \&_url_or_drop,
  bugtracker => sub { return _is_urlish($_[0]) ? { web => $_[0] } : undef },
  repository => sub { return _is_urlish($_[0]) ? { web => $_[0] } : undef },
  ':custom'  => \&_prefix_custom,
};

sub _upgrade_resources_2 {
  my (undef, undef, $meta, $version) = @_;
  return undef unless exists $meta->{resources};
  return _convert($meta->{resources}, $resource2_upgrade);
}

my $bugtracker2_spec = {
  web => \&_url_or_drop,
  mailto => \&_keep,
  ':custom'  => \&_prefix_custom,
};

my $repository2_spec = {
  web => \&_url_or_drop,
  url => \&_url_or_drop,
  type => \&_keep_or_unknown,
  ':custom'  => \&_prefix_custom,
};

my $resources2_cleanup = {
  license    => \&_url_list,
  homepage   => \&_url_or_drop,
  bugtracker => sub { ref $_[0] ? _convert( $_[0], $bugtracker2_spec ) : undef },
  repository => sub { ref $_[0] ? _convert( $_[0], $repository2_spec ) : undef },
  ':custom'  => \&_prefix_custom,
};

sub _cleanup_resources_2 {
  my ($resources, $key, $meta, $to_version) = @_;
  return undef unless $resources && ref $resources eq 'HASH';
  return _convert($resources, $resources2_cleanup, $to_version);
}

my $resource1_spec = {
  license    => \&_url_or_drop,
  homepage   => \&_url_or_drop,
  bugtracker => \&_url_or_drop,
  repository => \&_url_or_drop,
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
  my $resources = $meta->{resources} || {};
  if ( $meta->{license_url} && ! $resources->{license} ) {
    $resources->{license} = $meta->license_url
      if _is_urlish($meta->{license_url});
  }
  return undef unless keys %$resources;
  return _convert($resources, $resource1_spec);
}

my $resource_downgrade_spec = {
  license    => sub { return ref $_[0] ? $_[0]->[0] : $_[0] },
  homepage   => \&_url_or_drop,
  bugtracker => sub { return $_[0]->{web} },
  repository => sub { return $_[0]->{url} || $_[0]->{web} },
  ':custom'  => \&_ucfirst_custom,
};

sub _downgrade_resources {
  my (undef, undef, $meta, $version) = @_;
  return undef unless exists $meta->{resources};
  return _convert($meta->{resources}, $resource_downgrade_spec);
}

sub _release_status {
  my ($element, undef, $meta) = @_;
  return $element if $element =~ m{\A(?:stable|testing|unstable)\z};
  return _release_status_from_version(undef, undef, $meta);
}

sub _release_status_from_version {
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
    'name'                => \&_keep,
    'version'             => \&_keep,
    # CHANGED TO MANDATORY
    'dynamic_config'      => \&_keep_or_one,
    # ADDED MANDATORY
    'release_status'      => \&_release_status_from_version,
    # PRIOR OPTIONAL
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_upgrade_optional_features,
    'provides'            => \&_keep,
    'resources'           => \&_upgrade_resources_2,
    # ADDED OPTIONAL
    'description'         => \&_keep,
    'prereqs'             => \&_prereqs_from_1,

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
    'name'                => \&_keep,
    'version'             => \&_keep,
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
    'name'                => \&_keep,
    'version'             => \&_keep,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_optional_features_as_map,
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
    'version'             => \&_keep,
    # CHANGED TO MANDATORY
    'license'             => \&_license_1,
    'name'                => \&_keep,
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
    'optional_features'   => \&_optional_features_as_map,
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
    'version'             => \&_keep,
    # IMPLIED MANDATORY
    'name'                => \&_keep,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    # ADDED OPTIONAL
    'license_url'         => \&_url_or_drop,
    'private'             => \&_keep,

    # other random keys are OK if already valid
    ':custom'              => \&_keep
  },
);

my %down_convert = (
  '1.4-from-2' => {
    # MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_downgrade_license,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
    # OPTIONAL
    'build_requires'      => \&_get_build_requires,
    'configure_requires'  => \&_get_configure_requires,
    'conflicts'           => \&_get_conflicts,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_downgrade_optional_features,
    'provides'            => \&_keep,
    'recommends'          => \&_get_recommends,
    'requires'            => \&_get_requires,
    'resources'           => \&_downgrade_resources,

    # drop these unsupported fields (after conversion)
    ':drop' => [ qw(
      description
      prereqs
      release_status
    )],

    # custom keys will be left unchanged
    ':custom'              => \&_keep
  },
  '1.3-from-1.4' => {
    # MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
    # OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_optional_features_as_map,
    'provides'            => \&_keep,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    'resources'           => \&_resources_1_3,

    # drop these unsupported fields, but only after we convert
    ':drop' => [ qw(
      configure_requires
    )],

    # other random keys are OK if already valid
    ':custom'              => \&_keep,
  },
  '1.2-from-1.3' => {
    # MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
    # OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_1_2,
    'optional_features'   => \&_optional_features_as_map,
    'provides'            => \&_keep,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    'resources'           => \&_resources_1_3,

    # other random keys are OK if already valid
    ':custom'              => \&_keep,
  },
  '1.1-from-1.2' => {
    # MANDATORY
    'version'             => \&_keep,
    # IMPLIED MANDATORY
    'name'                => \&_keep,
    'meta-spec'           => \&_change_meta_spec,
    # OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'private'             => \&_keep,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,

    # drop unsupported fields
    ':drop' => [ qw(
      abstract
      author
      provides
      no_index
      keywords
      resources
    )],

    # other random keys are OK if already valid
    ':custom'              => \&_keep,
  },
  '1.0-from-1.1' => {
    # IMPLIED MANDATORY
    'name'                => \&_keep,
    'meta-spec'           => \&_change_meta_spec,
    'version'             => \&_keep,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,

    # other random keys are OK if already valid
    ':custom'              => \&_keep,
  },
);

my %cleanup = (
  '2' => {
    # PRIOR MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_2,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
    # CHANGED TO MANDATORY
    'dynamic_config'      => \&_keep_or_one,
    # ADDED MANDATORY
    'release_status'      => \&_release_status,
    # PRIOR OPTIONAL
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_cleanup_optional_features_2,
    'provides'            => \&_keep,
    'resources'           => \&_cleanup_resources_2,
    # ADDED OPTIONAL
    'description'         => \&_keep,
    'prereqs'             => \&_cleanup_prereqs,

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
  '1.4' => {
    # PRIOR MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
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

    # other random keys are OK if already valid
    ':custom'             => \&_keep
  },
  '1.3' => {
    # PRIOR MANDATORY
    'abstract'            => \&_keep_or_unknown,
    'author'              => sub { _listify( _keep_or_unknown( @_ ) ) },
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'keywords'            => \&_keep,
    'no_index'            => \&_no_index_directory,
    'optional_features'   => \&_optional_features_as_map,
    'provides'            => \&_keep,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    'resources'           => \&_resources_1_3,

    # other random keys are OK if already valid
    ':custom'             => \&_keep
  },
  '1.2' => {
    # PRIOR MANDATORY
    'version'             => \&_keep,
    # CHANGED TO MANDATORY
    'license'             => \&_license_1,
    'name'                => \&_keep,
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
    'optional_features'   => \&_optional_features_as_map,
    'provides'            => \&_keep,
    'resources'           => \&_resources_1_2,

    # other random keys are OK if already valid
    ':custom'             => \&_keep
  },
  '1.1' => {
    # CHANGED TO MANDATORY
    'version'             => \&_keep,
    # IMPLIED MANDATORY
    'name'                => \&_keep,
    'meta-spec'           => \&_change_meta_spec,
    # PRIOR OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,
    # ADDED OPTIONAL
    'license_url'         => \&_url_or_drop,
    'private'             => \&_keep,

    # other random keys are OK if already valid
    ':custom'             => \&_keep
  },
  '1.0' => {
    # IMPLIED MANDATORY
    'name'                => \&_keep,
    'meta-spec'           => \&_change_meta_spec,
    'version'             => \&_keep,
    # IMPLIED OPTIONAL
    'build_requires'      => \&_version_map,
    'conflicts'           => \&_version_map,
    'distribution_type'   => \&_keep,
    'dynamic_config'      => \&_keep_or_one,
    'generated_by'        => \&_generated_by,
    'license'             => \&_license_1,
    'recommends'          => \&_version_map,
    'requires'            => \&_version_map,

    # other random keys are OK if already valid
    ':custom'             => \&_keep,
  },
);

#--------------------------------------------------------------------------#
# Code
#--------------------------------------------------------------------------#

=method new

  my $cmc = CPAN::Meta::Converter->new( $struct );

The constructor should be passed a valid metadata structure but invalid
structures are accepted.  If no meta-spec version is provided, version 1.0 will
be assumed.

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

=for :list
* version
Indicates the desired specification version (e.g. "1.0", "1.1" ... "1.4", "2").
Defaults to the latest version of the CPAN Meta Spec.

The conversion process attempts to clean-up simple errors and standardize data
during converstion.  For example, if C<author> is given as a scalar, it will
converted to an array reference containing the item, or if a mandatory
C<license> field is missing, it will be added as "unknown".

Conversion proceeds through each version in turn.  For example, a version 1.2
structure is converted to 1.3 then 1.4 then finally version 2.  Converting a
structure to its own version will still clean-up and standardize the structure.

C<convert> will die if any conversion/standardization still results in an
invalid structure.

=cut

sub convert {
  my ($self, %args) = @_;
  my $args = { %args };

  my $new_version = $args->{version} || $HIGHEST;

  my ($old_version) = $self->{spec};
  my $converted = dclone $self->{data};

  if ( $old_version == $new_version ) {
    $converted = _convert( $converted, $cleanup{$old_version}, $old_version );
    my $cmv = CPAN::Meta::Validator->new( $converted );
    unless ( $cmv->is_valid ) {
      my $errs = join("\n", $cmv->errors);
      die "Failed to clean-up $old_version metadata. Errors:\n$errs\n";
    }
    return $converted;
  }
  elsif ( $old_version > $new_version )  {
    my @vers = sort { $b <=> $a } keys %known_specs;
    for my $i ( 0 .. $#vers-1 ) {
      next if $vers[$i] > $old_version;
      last if $vers[$i+1] < $new_version;
      my $spec_string = "$vers[$i+1]-from-$vers[$i]";
      $converted = _convert( $converted, $down_convert{$spec_string}, $vers[$i+1] );
      my $cmv = CPAN::Meta::Validator->new( $converted );
      unless ( $cmv->is_valid ) {
        my $errs = join("\n", $cmv->errors);
        die "Failed to downconvert metadata to $vers[$i+1]. Errors:\n$errs\n";
      }
    }
    return $converted;
  }
  else {
    my @vers = sort { $a <=> $b } keys %known_specs;
    for my $i ( 0 .. $#vers-1 ) {
      next if $vers[$i] < $old_version;
      last if $vers[$i+1] > $new_version;
      my $spec_string = "$vers[$i+1]-from-$vers[$i]";
      $converted = _convert( $converted, $up_convert{$spec_string}, $vers[$i+1] );
      my $cmv = CPAN::Meta::Validator->new( $converted );
      unless ( $cmv->is_valid ) {
        my $errs = join("\n", $cmv->errors);
        die "Failed to upconvert metadata to $vers[$i+1]. Errors:\n$errs\n";
      }
    }
    return $converted;
  }
}

1;

__END__

=head1 BUGS

Please report any bugs or feature using the CPAN Request Tracker.
Bugs can be submitted through the web interface at
L<http://rt.cpan.org/Dist/Display.html?Queue=CPAN-Meta>

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

=cut

