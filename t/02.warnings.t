#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/lib/common.pl';

BEGIN {plan tests => 8}


#List avec valeur non définie
  $test->setSource("<$tag name=\"nom\" list=\"\" />");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_UNDEFINED_LIST->{NO});

#List avec valeur non conforme
  $test->setSource("<$tag name=\"nom\" list=\"not list argument\" />");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_MALFORMED_LIST->{NO});

#Nullout vide
  $test->setSource("<$tag name=\"nom\" nullout=\"\" />");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_MALFORMED_NULLOUT->{NO});

#Nullout mal écrit
  $test->setSource("<$tag name=\"nom\" nullout=\"maybe\" />");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_MALFORMED_NULLOUT->{NO});

#Index non numeric
  $test->setSource("<$tag name=\"nom[zero]\" />");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_MALFORMED_INDEX->{NO});

#Un tag fermé non ouvert
  $test->setSource("a</$tag>b");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_UNMATCHED_OPENING->{NO});

#Un tag sans nom
  $test->setSource("<$tag />");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_TAG_NO_NAME->{NO});

#Donnée non disponible
  $test->setSource("<$tag name=\"not in data set\" />");
  $test->parse();
  ok(($test->getWarningsNo())[0] == Text::Templater::WAR_UNDEFINED_DATA->{NO});
