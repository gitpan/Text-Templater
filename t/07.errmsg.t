#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/lib/common.pl';

BEGIN {plan tests => 5}


#ERR_UNMATCHED_CLOSING
  $test->setSource( getfile('t/templates/err-001.tpl') );
  $test->parse();
  ok($test->getError() =~ m/.*1.*17$/);

#ERR_UNMATCHED_CLOSING
  $test->setSource("<$tag name=\"num\"><$tag name=\"num\" /></$tag><$tag name=\"num\">");
  $test->parse();
  ok($test->getError() =~ m/.*1.*57$/);
 
#WAR_UNMATCHED_OPENING
  $test->setSource("<$tag name=\"cmd\"></$tag></$tag>");
  $test->parse();
  ok(($test->getWarnings())[0] =~ m/.*1.*23$/);

#WAR_TAG_NO_NAME
  $test->setSource("<$tag name=\"cmd\"></$tag>\n<$tag />");
  $test->parse();
  ok(($test->getWarnings())[0] =~ m/.*2.*1$/);

#WAR_MALFORMED_NULLOUT
  $test->setSource("<$tag name=\"cmd\">\n\nall i want to do is love you<$tag name=\"cmd\" nullout=\"ERR\"/></$tag>");
  $test->parse();
  ok(($test->getWarnings())[0] =~ m/.*3.*29$/);
  
