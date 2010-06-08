use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta;

# 1.4 repository upgrade
{
  my $label = "(version 1.4) old repository winds up in 'web'";
  my $meta = CPAN::Meta->new(
    {
      name     => 'Module-Billed',
      abstract => 'inscrutable',
      version  => '1',
      author   => 'Joe',
      release_status => 'stable',
      license  => 'perl_5',
      dynamic_config => 1,
      generated_by   => 'hand',
      'meta-spec' => {
        version => '1.4',
        url     => 'http://module-build.sourceforge.net/META-spec-v1.4.html',
      },
      resources => {
        repository => 'http://example.com/',
      },
    },
    { lazy_validation => 1 },
  );

  is_deeply(
    $meta->resources,
    {
      repository => {
        web => 'http://example.com/',
      },
    },
    $label,
  );
}

{
  my $label = "(version 2  ) http in web passed through unchanged";
  my $meta = CPAN::Meta->new(
    {
      name     => 'Module-Billed',
      abstract => 'inscrutable',
      version  => '1',
      author   => 'Joe',
      release_status => 'stable',
      license  => 'perl_5',
      dynamic_config => 1,
      generated_by   => 'hand',
      'meta-spec' => {
        version => '2',
      },
      resources => {
        repository => {
          web => 'http://example.com/',
        },
      },
    },
    { lazy_validation => 1 },
  );


  is_deeply(
    $meta->{resources},
    {
      repository => {
        web => 'http://example.com/',
      },
    },
    $label
  );
}


done_testing;
