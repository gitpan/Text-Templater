#!/usr/bin/perl
use Module::Build;

my $build = Module::Build->new
  (
   module_name => 'Text::Templater',
   license => 'gpl',
   create_readme => 'false'
  );

$build->create_build_script;
