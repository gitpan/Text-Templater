#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/lib/common.pl';

BEGIN {plan tests => 8}

our $data_err = 
  {
  num =>
    [
      'nimporte quoi',
      'asdf'
    ]
  };


#Syntax correct
  $test->setSource("syntax ok");
  ok($test->parse() eq "syntax ok" && scalar $test->getWarnings() == 0);

#Un tag ouvert non fermé
  $test->setSource("<$tag name=\"nom\">oh no");
  $test->parse();
  ok($test->getErrorNo() == Text::Templater::ERR_UNMATCHED_CLOSING->{NO});
  
#Test du message d'erreur
  ok($test->getError() =~ m/.*1.*17$/);

#Aucune valeur de source 
  $test->setData(undef);
  $test->setSource(undef);
  $test->parse();
  ok($test->getErrorNo() == Text::Templater::ERR_NO_SOURCE->{NO});
  
#Test du message d'erreur
  ok($test->getError() =~ m/.*1.*1$/);

#Aucune valeur de data 
  $test->setSource("a<$tag name=\"patate\">b</$tag>c<$tag/>d");
  $test->setData(undef);
  ok($test->parse() eq "acd");

#Erreur dans la structure de data
  $test->setSource("<$tag name=\"num.lang[1]\" />");
  $test->setData($data_err);
  $test->parse();
  ok($test->getErrorNo() == Text::Templater::ERR_MALFORMED_STRUCTURE->{NO});

#Test du message d'erreur
  ok($test->getError() =~ m/.*1.*1$/);

  
