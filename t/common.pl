

our $tag = 'tpl';
our $tplfile;

our $data = 
  {
  nom => 
    [
    'Bob', 
    undef, 
    'Roger', 
    'Ponpon'
    ],
  cmd => 
    [
    'rm', 
    'ls', 
    'echo', 
    'cd'
    ],
  num =>
    [
      {
        lang => ['francais'],
        numeric => ['un', 'deux', 'trois', 'quatre'],
        deep => 
          [
            {
              test => ['1', '2', '3', '4'],
              sodeep =>
                [
                  {
                    test => ['1', '2', '3', '4']
                  }
                ]
            }
          ]
      },
      {
        lang => ['english'],
        numeric => ['one', 'two', 'three', 'four'],
      }
    ]
  };

our $test = new Text::Templater();
#our $test = new Text::Templater('c:tpl');
$test->setData($data);
  

sub getfile($)
{
  my $file = shift;
  my $template = '';

  open(FILE, $file) || die $!;
  $template .= $_ while(<FILE>);
  close(FILE);

  return $template;
}

sub testme($$$)
{
  my $template = getfile($tplfile);
  my $result = getfile($tplfile . '.result');
  my $parse;
  
  $test->setSource($template);
  $test->setData($data);
  $parse = $test->parse();
#print $parse;
  return  $parse eq $result;
}