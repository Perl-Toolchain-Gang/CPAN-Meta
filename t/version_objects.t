# Test that CPAN::Meta doesn't choke on version objects

use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta;
use Parse::CPAN::Meta;
use File::Temp 0.20 ();
use version 0.77;

# Fields to satisfy CPAN::Meta's requirements
my %defaults = (
    name                => "Foo::Bar",
    version             => "1.4.6",
    dynamic_config      => 0,
    author              => "Heywood",
    license             => "unknown",
    abstract            => "Awesome sauce 9000",
    release_status      => "stable",
);

note "version object as version"; {
    my $version = qv(1.2.3);

    my $meta = CPAN::Meta->create({
        %defaults,
        version => $version
    });

    my $struct = $meta->as_struct;
    is $struct->{version}, "$version";

    my $json = $meta->as_string;
    is( Parse::CPAN::Meta->load_json_string($json)->{version}, "$version" );

    my $yaml = $meta->as_string({ version => "1.4" });
    is( Parse::CPAN::Meta->load_yaml_string($yaml)->{version}, "$version" );
}


note "version object in provides"; {
    my $version = qv(2.3.4);
    my $meta = CPAN::Meta->create({
        %defaults,
        provides => {
            "This::That" => {
                file    => "lib/This/That.pm",
                version => $version
            }
        },
    });

    my $struct = $meta->as_struct;
    is $struct->{provides}{"This::That"}{version}, "$version";

    my $json = $meta->as_string;
    is( Parse::CPAN::Meta->load_json_string($json)->{provides}{"This::That"}{version}, "$version" );

    my $yaml = $meta->as_string({ version => "1.4" });
    is( Parse::CPAN::Meta->load_yaml_string($yaml)->{provides}{"This::That"}{version}, "$version" );
}

done_testing;
