#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/common.pl';

BEGIN {plan tests => 4}


#Syntax correct
  $test->setSource("syntax ok");
  ok($test->parse() eq "syntax ok" && $test->getWarnings() == 0);

#Un tag ouvert non fermé
  $test->setSource("<$tag name=\"nom\">oh no");
  ok(!defined $test->parse() && defined $test->getError());

#Aucune valeur de source 
  $test->setData(undef);
  $test->setSource(undef);
  ok(! defined $test->parse());

#Aucune valeur de data 
  $test->setSource("a<tpl name=\"patate\">b</$tag>c<$tag/>d");
  $test->setData(undef);
  ok($test->parse() eq "acd" && $test->getWarnings() > 0);
