#!/usr/bin/perl
use Text::Templater;
#use Templater::HTML;
use Benchmark;
use CGI;
#use DBI;

#my $dbh = DBI->connect('DBI:mysql:test', 'test', 'test');
#my $sql = "SELECT id, nom, prenom, num, texte FROM Templater";
#my $sth = $dbh->prepare($sql);
#$sth->execute();

my $data = {       #Faked cgi
  size    => ['2'],
  nom     => ['Bob', undef, 'Roger', 'Ponpon'],
  prenom  => ['Baker', 'CONST', 'Dupont', 'Jacques', 'Yves', '666', 'Number of heaven'],
  saisons => ['Hiver', 'Automne', 'Été', 'Printemps'],
  };
my $cgi = new CGI($data);

#==============================================================================

=pod
$count = 500;
timethis($count, sub {
  my $test  = new Templater();
  $test->setSource($test->getSourceFILE("template.txt"));
  $test->setData($cgi);
  $test->parse();
  });
=cut

#print "$count loops of other code took:",timestr($t),"\n";

my $test = new Text::Templater();
$test->setSource($test->getSourceFILE("test.txt"));
$test->setData($cgi);
print $test->parse();

#print $test->parseWith($test->getSourceFILE("template.txt"), $sth);

