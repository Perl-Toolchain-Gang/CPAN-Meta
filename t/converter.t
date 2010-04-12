use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta;
use File::Spec;
use IO::Dir;

my $data_dir = IO::Dir->new( 't/data' );
my @files = sort grep { /^\w/ } $data_dir->read;

use Data::Dumper;

for my $f ( @files ) {
  my $path = File::Spec->catfile('t','data',$f);
  my $original = CPAN::Meta->_load_file( $path  );
  ok( $original, "loaded $f" );
  $original->{'meta-spec'}{version} ||= '1.0';
  next unless $original->{'meta-spec'}{version} eq '1.4';
  my $meta = CPAN::Meta->load_file( $path );
  is ( $meta->meta_spec_version, 2, "loads are upconverted to spec version 2");
}

done_testing;

