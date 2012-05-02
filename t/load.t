use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta;
use File::Spec;
use IO::Dir;

sub _slurp { do { local(@ARGV,$/)=shift(@_); <> } }

note "convert metafile"; {
    my $meta = CPAN::Meta->load_file("t/data/META-1_4.yml");
    is $meta->{"meta-spec"}{version}, 2;

    $meta = CPAN::Meta->load_file("t/data/META-1_4.yml", {lazy_validation => 0});
    is $meta->{"meta-spec"}{version}, 2, "no lazy valiation";
}


note "don't convert"; {
    my $meta = CPAN::Meta->load_file("t/data/META-1_4.yml", { convert => 0 });
    is $meta->{"meta-spec"}{version}, 1.4;

    $meta = CPAN::Meta->load_file("t/data/META-1_4.yml", {lazy_validation => 0, convert => 0});
    is $meta->{"meta-spec"}{version}, 1.4, "no lazy valiation";
}


done_testing;
