use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta;

ok( my $meta = CPAN::Meta->load('t/data/META-1_4.yml'), '->load' );

is($meta->name,     'Module-Build', '->name');

done_testing;
