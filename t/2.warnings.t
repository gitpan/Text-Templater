#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/common.pl';

BEGIN {plan tests => 8}


#List avec valeur non définie
  $test->setSource("<$tag name=\"nom\" list=\"\" />");
  ok(defined $test->parse() && scalar $test->getWarnings() == 1);

#List avec valeur non conforme
  $test->setSource("<$tag name=\"nom\" list=\"not list argument\" />");
  ok(defined $test->parse() && scalar $test->getWarnings() == 1);
  
#Nullout vide
  $test->setSource("<$tag name=\"nom\" nullout=\"\" />");
  ok(defined $test->parse() && scalar $test->getWarnings() == 1);

#Nullout mal écrit
  $test->setSource("<$tag name=\"nom\" nullout=\"maybe\" />");
  ok(defined $test->parse() && scalar $test->getWarnings() == 1);
  
#Index non numeric
  $test->setSource("<$tag name=\"nom\" index=\"zero\" />");
  ok(defined $test->parse() && scalar $test->getWarnings() == 1);
  
#Un tag fermé non ouvert
  $test->setSource("a</$tag>b");
  ok($test->parse() eq 'ab' && $test->getWarnings() == 1);
  
#Un tag sans nom
  $test->setSource("<$tag />");
  ok(defined $test->parse() && scalar $test->getWarnings() == 1);
  
#Donnée non disponible
  $test->setSource("<$tag name=\"not in data set\" />");
  ok(defined $test->parse() && scalar $test->getWarnings() == 1);
