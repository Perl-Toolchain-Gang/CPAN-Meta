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

use Carp qw(carp confess);

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

sub _generated_by { __PACKAGE__ . " version " . (__PACKAGE__->VERSION || "<dev>") }

sub _listify { ref $_[0] eq 'ARRAY' ? $_[0] : [$_[0]] }

sub _prefix_custom { "x_" . $_[0] }

sub _change_meta_spec {
  my ($element, undef, undef, $version) = @_;
  $element->{version} = $version;
  $element->{url} = $known_specs{$version};
  return $element;
}

my %license_map_2 = (
  apache => 'apache_2_0',
  artistic => 'artistic_1',
  gpl => 'gpl_1',
  lgpl => 'lgpl_2_1',
  mozilla => 'mozilla_1_0',
  perl => 'perl_5',
);

sub _license_2 {
  my $element = ref $_[0] eq 'ARRAY' ? $_[0] : [$_[0]];
  for my $lic ( @$element ) {
    if ( my $new = $license_map_2{$lic} ) {
      $lic = $new;
    }
  }
  return $element;
}


sub _prereqs {
  my (undef, undef, $meta) = @_;
  my $prereqs = {};
  for my $phase ( qw/build configure/ ) {
    my $key = "${phase}_requires";
    $prereqs->{$phase}{requires} = $meta->{$key} if $meta->{$key};
  }
  for my $rel ( qw/requires recommends conflicts/ ) {
    $prereqs->{runtime}{$rel} = $meta->{$rel} if $meta->{$rel};
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
      prereqs => _prereqs->(undef, undef, $origin->{$name}),
    };
    delete $features->{$name}{prereqs}{configure};
  }
  return $features;
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

my $resource_conversion_spec = {
  license    => \&_listify,
  homepage   => \&_keep,
  bugtracker => sub { return $_[0] ? { web => $_[0] } : undef },
  repository => sub { return $_[0] ? { web => $_[0] } : undef },
  ':custom'  => \&_prefix_custom,
};

sub _resources_2 {
  my (undef, undef, $meta) = @_;
  return undef unless exists $meta->{resources};
  return _convert($meta->{resources}, $resource_conversion_spec);
}

sub _convert {
  my ($data, $spec, $to_version) = @_;

  my $new_data = {};
  for my $key ( %$spec ) {
    next if $key eq ':custom' || $key eq ':drop';
    next unless my $fcn = $spec->{$key};
    my $new_value = $fcn->($data->{$key}, $key, $data, $to_version);
    $new_data->{$key} = $new_value if defined $new_value;
  }

  my $drop_list   = $spec->{':drop'};
  my $customizer  = $spec->{':custom'};

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
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
    'abstract'            => \&_keep,
    'author'              => \&_listify,
    'license'             => \&_license_2,
    'generated_by'        => \&_generated_by,
    'dynamic_config'      => \&_keep_or_one,
    'prereqs'             => \&_prereqs,
    'optional_features'   => \&_optional_features_2,
    'provides'            => \&_keep,
    'no_index'            => \&_keep,
    'keywords'            => \&_keep,
    'resources'           => \&_resources_2,

    # drop these deprecated fields, but only after we convert
    ':drop' => [ qw(
        requires build_requires recommends conflicts configure_requires
        private distribution_type
    ) ],

    # other random keys need x_ prefixing
    ':custom'              => \&_prefix_custom,
  },
  '1.4-from-1.3' => {
    'meta-spec'           => \&_change_meta_spec,
    'name'                => \&_keep,
    'version'             => \&_keep,
    'abstract'            => \&_keep,
    'author'              => \&_keep,
    'license'             => \&_keep,
    'generated_by'        => \&_generated_by,
    'dynamic_config'      => \&_keep_or_one,
#    configure_requires -- didn't exist prior to 1.4
    'build_requires'      => \&_keep,
    'requires'            => \&_keep,
    'recommends'          => \&_keep,
    'conflicts'           => \&_keep,
    'optional_features'   => \&_optional_features_1,
    'provides'            => \&_keep,
    'no_index'            => \&_keep,
    'keywords'            => \&_keep,
    'resources'           => \&_resources_1,

    # drop these deprecated fields, but only after we convert
    ':drop' => [ qw/ private / ],

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
    my $conversion_spec = $up_convert{"${new_version}-from-${old_version}"};
    die "converting from $old_version to $new_version not supported"
      unless $conversion_spec;
    return _convert( $self->{data}, $conversion_spec, $new_version );
  }
}

1;
