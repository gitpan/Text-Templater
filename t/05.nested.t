#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/lib/common.pl';

BEGIN {plan tests => 6}


#Donn�s imbriqu� � 2 niveau ferm�
  $test->setSource("<$tag name=\"num.lang\" />");
  ok($test->parse() eq 'francais' && scalar $test->getWarnings() == 0);
  
#Donn�s imbriqu� � 3 niveau ferm�
  $test->setSource("<$tag name=\"num.deep.test\" />");
  ok($test->parse() eq '1' && scalar $test->getWarnings() == 0);
  
#Donn�s imbriqu� � 4 niveau ferm�
  $test->setSource("<$tag name=\"num.deep.sodeep.test\" />");
  ok($test->parse() eq '1' && scalar $test->getWarnings() == 0);
  
#Donn�s imbriqu� � 2 niveau ouvert
  $test->setSource("<$tag name=\"num.numeric\"><$tag name=\"num.deep.test\"><$tag name=\"num.deep.test\" /></$tag>-</$tag>");
  ok($test->parse() eq '1234-1234-1234-1234-' && scalar $test->getWarnings() == 0);

#� un niveau avec index
  $test->setSource("<$tag name=\"num[1].lang\" />");
  ok($test->parse() eq 'english' && scalar $test->getWarnings() == 0);

#Donn�s imbriqu� � 4 niveau ferm�
  $test->setSource("<$tag name=\"num.deep[1].sodeep.test[0]\" />");
  ok($test->parse() eq 'a' && scalar $test->getWarnings() == 0);

