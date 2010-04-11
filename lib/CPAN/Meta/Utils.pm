use strict;
use warnings;
package CPAN::Meta;

use Carp qw(confess);

sub __string  { defined $_[0] && ! ref $_[0] };
sub __list    { defined ref $_[0] && ref_[0] eq 'ARRAY' };
sub __map     { defined ref $_[0] && ref_[0] eq 'HASH' };

my %spec_validators = (
  '1.0' => {

  },
  '1.1' => {

  },
  '1.2' => {

  },
  '1.3' => {

  },
  '1.4' => {

  },
);




1;
