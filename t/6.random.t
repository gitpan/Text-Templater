#!/usr/bin/perl
use Test;
use Text::Templater;

require 't/common.pl';

BEGIN {plan tests => 2}


#001
  $tplfile = 't/templates/001.tpl';
  ok(\&testme);

#002
  $tplfile = 't/templates/002.tpl';
  ok(\&testme);
