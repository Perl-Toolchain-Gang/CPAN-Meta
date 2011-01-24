use strict;
use warnings;
use Test::More 0.88;

use CPAN::Meta;
use File::Temp 0.20 ();
use Parse::CPAN::Meta 1.4200;

my $distmeta = {
  name     => 'Module-Build',
  abstract => 'Build and install Perl modules',
  description =>  "Module::Build is a system for building, testing, "
              .   "and installing Perl modules.  It is meant to be an "
              .   "alternative to ExtUtils::MakeMaker... blah blah blah",
  version  => '0.36',
  author   => [
    'Ken Williams <kwilliams@cpan.org>',
    'Module-Build List <module-build@perl.org>', # additional contact
  ],
  release_status => 'stable',
  license  => [ 'perl_5' ],
  prereqs => {
    runtime => {
      requires => {
        'perl'   => '5.006',
        'Config' => '0',
        'Cwd'    => '0',
        'Data::Dumper' => '0',
        'ExtUtils::Install' => '0',
        'File::Basename' => '0',
        'File::Compare'  => '0',
        'File::Copy' => '0',
        'File::Find' => '0',
        'File::Path' => '0',
        'File::Spec' => '0',
        'IO::File'   => '0',
      },
      recommends => {
        'Archive::Tar' => '1.00',
        'ExtUtils::Install' => '0.3',
        'ExtUtils::ParseXS' => '2.02',
        'Pod::Text' => '0',
        'YAML' => '0.35',
      },
    },
    build => {
      requires => {
        'Test::More' => '0',
      },
    }
  },
  resources => {
    license => ['http://dev.perl.org/licenses/'],
  },
  optional_features => {
    domination => {
      description => 'Take over the world',
      prereqs     => {
        develop => { requires => { 'Genius::Evil'     => '1.234' } },
        runtime => { requires => { 'Machine::Weather' => '2.0'   } },
      },
    },
  },
  dynamic_config => 1,
  keywords => [ qw/ toolchain cpan dual-life / ],
  'meta-spec' => {
    version => '2',
    url     => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
  },
  generated_by => 'Module::Build version 0.36',
};

my $meta = CPAN::Meta->new( $distmeta );

my $tmpdir = File::Temp->newdir();
my $metafile = File::Spec->catfile( $tmpdir, 'META.json' );

$meta->save($metafile);
ok( -f $metafile, "save meta to file" );

ok( $meta = Parse::CPAN::Meta->load_file($metafile), 'load saved file' );
is($meta->{name},     'Module-Build', 'name correct');


ok( $meta = Parse::CPAN::Meta->load_file('t/data/META-1_4.yml'), 'load META-1.4' );
is($meta->{name},     'Module-Build', 'name correct');

done_testing;
