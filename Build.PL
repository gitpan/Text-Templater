use Module::Build;

my $build = Module::Build->new
  (
   module_name => 'Text::Templater',
   license => 'perl',
   create_readme => 'true'
  );

$build->create_build_script;
