use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta;
use CPAN::Meta::Validator;
use CPAN::Meta::Converter;
use File::Spec;
use IO::Dir;

my $data_dir = IO::Dir->new( 't/data' );
my @files = sort grep { /^\w/ } $data_dir->read;

sub _spec_version { return $_[0]->{'meta-spec'}{version} || "1.0" }

use Data::Dumper;

for my $f ( @files ) {
  my $path = File::Spec->catfile('t','data',$f);
  my $original = CPAN::Meta->_load_file( $path  );
  ok( $original, "loaded $f" );
  my $original_v = _spec_version($original);
  SKIP: {
    skip "upconverting $original_v not supported yet", 2
      unless $original_v > 1.3;

    my $cmc = CPAN::Meta::Converter->new( $original );
    my $converted = $cmc->convert( version => 2 );
    is ( _spec_version($converted), 2, "converted $original_v to spec version 2");
    my $cmv = CPAN::Meta::Validator->new( $converted );
    ok ( $cmv->is_valid, "converted META is valid" )
      or diag( "ERRORS:\n" . join( "\n", $cmv->errors ) . "\nMETA:\n"
      . Dumper($converted)
    );
  }
}

done_testing;

