#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/lib/common.pl';

BEGIN {plan tests => 4}


#Tag ouvert
  $test->setSource("<$tag name=\"nom\">t</$tag>");
  ok($test->parse() eq 'tttt' && scalar $test->getWarnings() == 0);
  
#Tag ouvert avec tag fermé
  $test->setSource("<$tag name=\"nom\"><$tag name=\"nom\" /></$tag>");
  ok($test->parse() eq 'BobRogerPonpon' && scalar $test->getWarnings() == 0);
  
#Tag ouvert imbriqué
  $test->setSource("<$tag name=\"nom\"><$tag name=\"nom\">t</$tag>-</$tag>");
  ok($test->parse() eq 'tttt-tttt-tttt-tttt-' && scalar $test->getWarnings() == 0);
  
#Tag ouvert imbriqué et tag fermé
  $test->setSource("<$tag name=\"nom\"><$tag name=\"nom\" />:<$tag name=\"nom\"><$tag name=\"nom\" /></$tag>-</$tag>");
  ok($test->parse() eq 'Bob:BobRogerPonpon-:BobRogerPonpon-Roger:BobRogerPonpon-Ponpon:BobRogerPonpon-'
    && scalar $test->getWarnings() == 0);
