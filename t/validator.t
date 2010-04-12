use strict;
use warnings;
use Test::More 0.88;

use Parse::CPAN::Meta;
use CPAN::Meta::Validator;
use File::Spec;
use IO::Dir;

my $data_dir = IO::Dir->new( 't/data' );
my @files = sort grep { /^\w/ } $data_dir->read;

for my $f ( @files ) {
  my @yaml = Parse::CPAN::Meta::LoadFile( File::Spec->catfile('t','data',$f) );
  my $cmv = CPAN::Meta::Validator->new($yaml[0]);
  ok( $cmv->is_valid, "$f validates" ) 
    or diag( "ERRORS:\n" . join( "\n", $cmv->errors ) );
}

done_testing;

