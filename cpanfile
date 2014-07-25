requires "CPAN::Meta::Requirements" => "2.121";
requires "CPAN::Meta::YAML" => "0.008";
requires "Carp" => "0";
requires "JSON::PP" => "2.27200";
requires "Parse::CPAN::Meta" => "1.4414";
requires "Scalar::Util" => "0";
requires "perl" => "5.008";
requires "strict" => "0";
requires "version" => "0.88";
requires "warnings" => "0";

on 'test' => sub {
  requires "Data::Dumper" => "0";
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Basename" => "0";
  requires "File::Spec" => "0";
  requires "File::Spec::Functions" => "0";
  requires "File::Temp" => "0.20";
  requires "IO::Dir" => "0";
  requires "List::Util" => "0";
  requires "Scalar::Util" => "0";
  requires "Test::More" => "0.88";
  requires "overload" => "0";
  requires "utf8" => "0";
  requires "version" => "0.88";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "0";
  recommends "CPAN::Meta::Prereqs" => "0";
  recommends "CPAN::Meta::Requirements" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.17";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "5";
  requires "Dist::Zilla::Plugin::AutoVersion" => "0";
  requires "Dist::Zilla::Plugin::MakeMaker" => "0";
  requires "Dist::Zilla::Plugin::MakeMaker::Highlander" => "0.003";
  requires "Dist::Zilla::Plugin::OnlyCorePrereqs" => "0.013";
  requires "Dist::Zilla::Plugin::Prereqs" => "0";
  requires "Dist::Zilla::PluginBundle::DAGOLDEN" => "0.053";
  requires "File::Spec" => "0";
  requires "File::Temp" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::More" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Spelling" => "0.12";
};
