#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/lib/common.pl';

BEGIN {plan tests => 13}


#Valeur associé avec name
  $test->setSource("<$tag name=\"nom\" />");
  ok($test->parse() eq 'Bob' && scalar $test->getWarnings() == 0);
  
#Id tag fermé
  $test->setSource("<$tag id=\"patate\" name=\"nom\" /><a x=\"#patate\">");
  ok($test->parse() eq '<a x="Bob">' && scalar $test->getWarnings() == 0);
  
#Deux id tag fermé
  $test->setSource("<$tag id=\"patate\" name=\"nom\" /><$tag id=\"command\" name=\"cmd\" /><a x=\"#patate\"><a x=\"#command\">");
  ok($test->parse() eq '<a x="Bob"><a x="rm">' && scalar $test->getWarnings() == 0);
  
#Trois id tag fermé
  $test->setSource("<$tag id=\"patate\" name=\"nom\" /><$tag id=\"command\" name=\"cmd\" /><$tag id=\"patate\" name=\"nom\" /><a x=\"#patate\"><a x=\"#command\"><a x=\"#patate\">");
  ok($test->parse() eq '<a x="Bob"><a x="rm"><a x="Bob">' && scalar $test->getWarnings() == 0);
  
#Id tag ouvert
  $test->setSource("<$tag id=\"patate\" name=\"nom\"><a x=\"#patate\"></$tag>");
  ok($test->parse() eq '<a x="Bob"><a x=""><a x="Roger"><a x="Ponpon">' && scalar $test->getWarnings() == 0);
  
#Nullout
  $test->setSource("<$tag name=\"nom\" nullout=\"yes\">t</$tag>");
  ok($test->parse() eq 'ttt' && scalar $test->getWarnings() == 0);
  
#List
  $test->setSource("<$tag name=\"nom\" list=\"X:1,2,3\">X</$tag>");
  ok($test->parse() eq '1231' && scalar $test->getWarnings() == 0);
  
#Index avec valeur négative
  $test->setSource("<$tag name=\"nom[-1]\" />");
  ok($test->parse() eq 'Ponpon' && scalar $test->getWarnings() == 0);
  
#Index avec valeur négative plus grand que la taille des données
  $test->setSource("<$tag name=\"nom[-100]\" />");
  ok($test->parse() eq 'Bob' && scalar $test->getWarnings() == 0);
  
#Index positif
  $test->setSource("<$tag name=\"nom[2]\" />");
  ok($test->parse() eq 'Roger' && scalar $test->getWarnings() == 0);
  
#Index positif avec valeur plus grand que taille des données
  $test->setSource("<$tag name=\"nom[100]\" />");
  ok($test->parse() eq '' && scalar $test->getWarnings() == 0);
  
#Index positif avec valeur plus grand que taille des données
  $test->setSource("<$tag name=\"nom[0]\" />");
  ok($test->parse() eq 'Bob' && scalar $test->getWarnings() == 0);

#Impression d'une valeur undef
  $test->setSource("<$tag name=\"nom[1]\" />");
  ok($test->parse() eq '' && scalar $test->getWarnings() == 0);
