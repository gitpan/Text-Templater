#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/common.pl';

BEGIN {plan tests => 14}


#Valeur associé avec name
  $test->setSource("<$tag name=\"nom\" />");
  ok($test->parse() eq 'Bob' && $test->getWarnings() == 0);
  
#Id tag fermé
  $test->setSource("<$tag id=\"patate\" name=\"nom\" /><a x=\"#patate\">");
  ok($test->parse() eq '<a x="Bob">' && $test->getWarnings() == 0);
  
#Deux id tag fermé
  $test->setSource("<$tag id=\"patate\" name=\"nom\" /><$tag id=\"command\" name=\"cmd\" /><a x=\"#patate\"><a x=\"#command\">");
  ok($test->parse() eq '<a x="Bob"><a x="rm">' && $test->getWarnings() == 0);
  
#Trois id tag fermé
  $test->setSource("<$tag id=\"patate\" name=\"nom\" /><$tag id=\"command\" name=\"cmd\" /><$tag id=\"patate\" name=\"nom\" /><a x=\"#patate\"><a x=\"#command\"><a x=\"#patate\">");
  ok($test->parse() eq '<a x="Bob"><a x="rm"><a x="Bob">' && $test->getWarnings() == 0);
  
#Id tag ouvert
  $test->setSource("<$tag id=\"patate\" name=\"nom\"><a x=\"#patate\"></$tag>");
  ok($test->parse() eq '<a x="Bob"><a x=""><a x="Roger"><a x="Ponpon">' && $test->getWarnings() == 0);
  
#Index
  $test->setSource("<$tag name=\"nom\" index=\"2\"/>");
  ok($test->parse() eq 'Roger' && $test->getWarnings() == 0);
  
#Nullout
  $test->setSource("<$tag name=\"nom\" nullout=\"yes\">t</$tag>");
  ok($test->parse() eq 'ttt' && $test->getWarnings() == 0);
  
#List
  $test->setSource("<$tag name=\"nom\" list=\"X:1,2,3\">X</$tag>");
  ok($test->parse() eq '1231' && $test->getWarnings() == 0);
  
#Index avec valeur négative
  $test->setSource("<$tag name=\"nom\" index=\"-1\" />");
  ok($test->parse() eq 'Ponpon' && $test->getWarnings() == 0);
  
#Index avec valeur négative plus grand que la taille des données
  $test->setSource("<$tag name=\"nom\" index=\"-100\" />");
  ok($test->parse() eq 'Bob' && $test->getWarnings() == 0);
  
#Index positif
  $test->setSource("<$tag name=\"nom\" index=\"2\" />");
  ok($test->parse() eq 'Roger' && $test->getWarnings() == 0);
  
#Index positif avec valeur plus grand que taille des données
  $test->setSource("<$tag name=\"nom\" index=\"100\" />");
  ok($test->parse() eq '' && $test->getWarnings() == 0);
  
#Index positif avec valeur plus grand que taille des données
  $test->setSource("<$tag name=\"nom\" index=\"0\" />");
  ok($test->parse() eq 'Bob' && $test->getWarnings() == 0);

#Impression d'une valeur undef
  $test->setSource("<$tag name=\"nom\" index=\"1\" />");
  ok($test->parse() eq '' && $test->getWarnings() == 0);
