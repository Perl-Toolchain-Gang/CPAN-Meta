use strict;
use warnings;
package CPAN::Meta::Converter;
# ABSTRACT: Convert CPAN distribution metadata structures

use Carp qw(carp confess);

my %known_specs = (
    '2'   => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
    '1.4' => 'http://module-build.sourceforge.net/META-spec-v1.4.html',
    '1.3' => 'http://module-build.sourceforge.net/META-spec-v1.3.html',
    '1.2' => 'http://module-build.sourceforge.net/META-spec-v1.2.html',
    '1.1' => 'http://module-build.sourceforge.net/META-spec-v1.1.html',
    '1.0' => 'http://module-build.sourceforge.net/META-spec-v1.0.html'
);

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

sub _generated_by { __PACKAGE__ . " version " . __PACKAGE__->VERSION }

sub _listify { ref $_[0] eq 'ARRAY' ? $_[0] : [$_[0]] }

sub _prefix_custom { "x_" . $_[0] }

sub _change_meta_spec {
  my ($element, undef, undef, $version) = @_;
  $element->{version} = $version;
  $element->{url} = $known_specs{$version};
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
  bugtracker => sub { return { web => $_[0] } },
  repository => sub { return { web => $_[0] } },
  ':custom'  => \&_prefix_custom,
};

sub _resources_2 {
  my (undef, undef, $meta) = @_;
  return undef unless exists $meta->{resources};
  return _convert($meta->{resource}, $resource_conversion_spec);
}

sub _convert {
  my ($data, $spec, $to_version) = @_;

  my $new_data = {};
  for my $key ( %$spec ) {
    next if $key eq ':custom' || $key eq ':drop';
    next unless my $fcn = $spec->{$key};
    $new_data->{$key} = $fcn->($data->{$key}, $key, $data, $to_version);
  }

  my $drop_list   = $spec->{':drop'};
  my $customizer  = $spec->{':custom'};

  for my $key ( keys %$data ) {
    next if $drop_list && grep { $key eq $_ } @$drop_list;
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
    'license'             => \&_listify,
    'generated_by'        => \&_generated_by,
    'dynamic_config'      => \&_keep_or_one,
    'prereqs'             => \&_prereqs,
    'optional_features'   => \&_optional_features_2,
    'provides'            => \&_keep,
    'no_index'            => \&_keep,
    'keywords'            => \&_keep,
    'resources'           => \&_resources_2,

    # drop these deprecated fields, but only after we convert
    ':drop' => [ qw/ private distribution_type / ],

    # other random keys need x_ prefixing
    ':custom'              => \&_prefix_custom,
  },
);


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

sub convert_to {
  my ($self, $new_version) = @_;
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
