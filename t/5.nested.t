#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/common.pl';

BEGIN {plan tests => 4}


#Donnés imbriqué à 2 niveau fermé
  $test->setSource("<$tag name=\"num.lang\" />");
  ok($test->parse() eq 'francais');
  
#Donnés imbriqué à 3 niveau fermé
  $test->setSource("<$tag name=\"num.deep.test\" />");
  ok($test->parse() eq '1');
  
#Donnés imbriqué à 4 niveau fermé
  $test->setSource("<$tag name=\"num.deep.sodeep.test\" />");
  ok($test->parse() eq '1');
  
#Donnés imbriqué à 2 niveau ouvert
  $test->setSource("<$tag name=\"num.numeric\"><$tag name=\"num.deep.test\"><$tag name=\"num.deep.test\" /></$tag>-</$tag>");
  ok($test->parse() eq '1234-1234-1234-1234-');
