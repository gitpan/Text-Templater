package Text::Templater;
use strict;
use warnings;

our $VERSION = 1.1;
our @ISA     = ();

sub new();
sub setSource($);
sub setData($);
sub getDataCGI($;);
sub getDataSTH($;);
sub getSourceFILE($);
sub parse(;$$);
sub _getNextNode($;);
sub _makeList($;);
sub _replaceConst($$$;);
sub _getPosEnd($$;);

#Constructeur de l'objet.
#Il est possible de lui passer en parametre, un nom specifique
#de tag à utiliser pendant la duree de l'objet.
sub new()
{
  my $class = shift;
  my $self = {
    TAGNAME    => "tpl",
    source     => '',
    data       => {},
    index      => 0,    #Index par defaut des valeurs.
    nullout    => "no", #Valeurs par defaut du parametre nullout.
    };
  return bless $self, $class;
}

#Ajuste la source (le template) et retourne le resultat.
sub setSource($)
{
  my $self = shift;
  if(@_){
    $self->{source} = shift;
  }
  return $self->{source};
}

#Ajuste les donnees (les information a mettre dans le template).
#Les donnees doivent etre une reference a un hash dont les
#values sont des reference a un array {v1 => [0,1]}.
#Si un objet CGI ou STH est passe, il est automatiquement convertie.
sub setData($)
{
  my ($self, $data) = (shift, {});
  if(@_){
    $data = shift;

    if(ref $data eq 'CGI'){
      $data = $self->getDataCGI($data);
    }
    elsif(ref $data eq 'DBI::st'){
      $data = $self->getDataSTH($data);
    }
    $self->{data} = $data;
  }
  return $self->{data};
}

#Prend un objet CGI et le transforme dans le format
#de donnees utilise par Templater.
sub getDataCGI($;)
{
  my ($self, $cgi, $data) = (shift, shift, {});
  return $cgi if(ref $cgi ne 'CGI');

  foreach my $key ($cgi->param){
    $data->{$key} = [$cgi->param($key)];
  }
  return $data;
}

#Prend un objet STH et le transforme dans le format
#de donnees utilise par Templater.
sub getDataSTH($;)
{
  my ($self, $sth, $data) = (shift, shift, {});
  my ($key, $ary);

  while($ary = $sth->fetchrow_hashref()){
    foreach $key (keys %$ary){
      push @{$data->{$key}}, $ary->{$key};
    }
  }
  return $data;
}

#Prend en parametre un nom de fichier, le lie et
#retourne sont contenu. undef est retourne si
#l'ouverture ou la fermeture du fichier à echoue.
sub getSourceFILE($)
{
   my ($self, $file, $template) = (shift, shift, undef);
   return undef unless(defined($file));

   return undef unless(open(FILE, $file));
   $template .= $_ while(<FILE>);
   return undef unless(close(FILE));

   return $template;
}

#Effectue un remplacement des tags <tpl /> à l'interieur
#de la source et retourne le resultat.
#Les parametre optionel sont les suivant: la source et l'index.
#Si les parametre ne sont pas specifier, les valeurs par defaut
#sont prisent pour acquise.
sub parse(;$$)
{
  my ($self, $val, %node) = (shift, '', ());
  my $source  = defined($_[0]) ? shift : $self->{source};
  my $index   = defined($_[0]) ? shift : $self->{index};
  return $source if($source eq '');

  while((%node = $self->_getNextNode($source)) && defined($node{tag})){
    if(!defined($node{key})){
      $val = ''; }
    elsif(!defined($node{inner})){
      $node{index} = $index if(!defined($node{index}));
      $val = $self->{data}->{$node{key}}[$node{index}];
    }
    else{
      $node{index} = $self->{index} if(!defined($node{index}));
      $node{nullout} = $self->{nullout} if(!defined($node{nullout}));
      for(my $i = $node{index}; !defined $self->{data}->{$node{key}} || $i < scalar @{$self->{data}->{$node{key}}}; $i++){
        $val .= $self->parse($self->_replaceConst($node{inner}, $node{list}, $i), $i)
          if($node{nullout} eq "no" || (defined($self->{data}->{$node{key}}[$i]) && $self->{data}->{$node{key}}[$i] ne ""));
      }
    }
  } continue{
    $val = '' if(!defined($val));
    $source =~ s/\Q$node{tag}\E/$val/;
    $val = '';
  }
  return $source;
}

#Recoit un template et retourne le prochain tag trouve.
#Le tag est represente dans un hash contenant les clefs suivante :
#tag, inner, key, nullout, index et list.
sub _getNextNode($;)
{
  my ($self, $source) = (shift, shift);
  my ($pos, $posend, $tag, $tagend, @list, %res);
  $source =~ m/(<\Q$self->{TAGNAME}\E[^>]*?>)/gs;
  ($res{tag}, $tag, $pos) = ($1, $1, pos($source));
  return %res if(!defined($res{tag}));

  if($tag !~ m/\/>$/){  #Tag avec du contenu..
    ($posend, $tagend) = $self->_getPosEnd($source, pos($source));
    $pos = $pos - length $res{tag};
    $res{tag} = $res{inner} = substr($source, $pos, $posend - $pos);
    $res{inner} =~ s/^\Q$tag\E(.*)\Q$tagend\E$/$1/s;
  }

  $res{key}     = $1 if($res{tag} =~ m/^<[^>]*?name="(.*?)"[^>]*?>/);
  $res{nullout} = $1 if($res{tag} =~ m/^<[^>]*?nullout="(.*?)"[^>]*?>/);
  $res{index}   = $1 if($res{tag} =~ m/^<[^>]*?index="(.*?)"[^>]*?>/);
  while($tag =~ m/list="(.*?)"/g){ push(@list, $1); }
  %{$res{list}} = $self->_makeList(@list);

  return %res;
}

#Prend en parametre une liste de parametre list non decortique,
#sous forme "CONST:v1,v2,v3,..." et retourne un hash des valeurs.
#Si une constante est définie plus d'une fois, le resultat est
#celui de la derniere definition.
sub _makeList($;)
{
  my ($self, @src, %res) = (shift, @_, ());
  my ($const, $vals, $list);
  foreach $list (@src){
    if($list =~ m/(.*?):(.*)/){
      ($const, $vals) = ($1, $2);
      $vals =~ s/\\,/\0/; $vals =~ s/\\(.)/$1/;
      $res{$const} = [split(/,/, $vals)];
      map { s/\0/,/g; s/^\s*//g; s/\s*$//g; } @{$res{$const}};
    }
  }
  return %res;
}

#Prend en parametre la source, le hash des constantes et leurs
#valeurs ainsi que l'index actuel.
#Les valeurs tournent en rond (v1,v2,v3), index 5 == v2
sub _replaceConst($$$;)
{
  my ($self, $src, $const, $index) = @_;
  my ($inx, $start, $end, $tmp, $tmp2, $tag, $pos);
  return $src if(scalar keys %$const == 0);

  foreach my $key (keys %$const){
    $inx = ($index > scalar @{$const->{$key}}-1) ?
      $index % scalar @{$const->{$key}} : $index;

    for($start = $end = 0; $start < length $src; $start = $end, $tag = ''){
      pos($src) = $start;
      if($src =~ m/(<\Q$self->{TAGNAME}\E[^>]*?>)/gs){
        ($tag, $pos) = ($1, pos($src));
        $end = $pos - length $tag;
      }
      else{ $end = length $src; }

      $tmp = $tmp2 = substr($src, $start, $end - $start);
      $tmp =~ s/\Q$key\E(\W+)/$const->{$key}->[$inx]$1/g;
      $src =~ s/\Q$tmp2\E/$tmp/;

      ($end, $tmp) = ($tag =~ m/\/>$/) ?
        ($end + length $tag, '') : $self->_getPosEnd($src, $pos)
          if($tag ne '');
    }
  }
  return $src;
}

#Prend la source de donnee et retourne la position du
#tag fermant correspondant en renant pour acquis qu'un
#tag ouvert a bel et bien trouve.
#Si il ne trouve pas la fin, la fin est length $src
sub _getPosEnd($$;)
{
  my ($self, $src, $start) = (@_);
  my ($count, $pos, $tag);
  pos($src) = $start;
  for($count = 1; $count > 0 && $src =~ m/(<[^>]*?\Q$self->{TAGNAME}\E[^>]*?>)/g; ){
    ($pos, $tag) = (pos($src), $1);
    $count = ($tag =~ m/^<\//) ? --$count : ++$count
      if($tag !~ m/\/>$/);
  }

  die "Unmatched closing tag in :\n$src" if($count != 0);
  return ($pos, $tag);
}



1;
__END__

=pod

=head1 NAME

Templater - Parse data into a template.

=head1 SYNOPSIS

   #!/usr/bin/perl
   use Text::Templater;

   my $tpl = new Text::Templater();

   $tpl->setSource($sometemplate);
   $tpl->setSource($tpl->getSourceFILE("myfile"));

   $tpl->setData({                  # Set the data source.
      name => ['bob', undef, 'daniel'],
      color => ['red', 'green', 'blue'],
      });
   $tpl->setData($cgi);             # Or use existing objects.
   $tpl->setData($sth);

   print $tpl->parse();             # Get the result.


=head1 ABSTRACT

The objective of the Templater object is to separate data manipulation from
it's representation while keeping out logic as much as possible from the representation side.

=head1 DESCRIPTION

Templater receive the template and the data to be binded in the template.
Then using the parse method, it return the result.

One tag and 4 properties are defined in a xml'ish way to describe data in the template.

<tpl name="key" index="0" nullout="no" list="CONST:1,2,3..." />


=head2 Tag properties

=over

=item name="name"

  You can bind a specific data value to a tag using it's hash key.
  A tag without a name does not make sense.
  In the synopsis; <tpl name="color" /> eqals red.

=item index="num"

  Specify the index of the value to be binded.
  If not specified, the current iteration is taken.
  In the synopsis; <tpl name="color" index="1" /> eqals green.

=item nullout="yes|no"

  If the binded value is undef or '', all the expression
  is discarded. no is taken by default.
  In the synopsis; <tpl name="name" index="1" nullout="yes">hi</tpl> equals nothing.

=item list="CONST:1,2,3,..."

  Defines a specific constant "CONST" into the tag inner source.
  The value of CONST will alternativly be 1, 2, 3, 1, 2, ...
  The backslash is used as a dummy quote character.
  But no, you can't \u or \b :-)

=back

=head2 Tag forms

The templater tag can be written as:
<tpl /> or <tpl></tpl>.
The first form will replace the tag with the corresponding binded data.
The second form will loop each value of the binded data; the concatenation
of each result is used as the sole result.

=head2 Methods

=over

=item new

Creates a new Templater object.

=item setSource

If a scalar is passed, it is set to be the template.
The source of the object is returned.

=item setData

If a value is passed, it is set to be the data to bind.
CGI and STH objects can be passed.
The data of the object is returned.

=item getDataCGI

Return the converted cgi given in argument into the
data structure used by the object.

=item getDataSTH

Return the converted sth given in argument into the
data structure used by the object.

=item getSourceFILE

This simple utility method is used to read a file.

=item parse

Takes the template and parse the data inside using the
templater tags. The parsed template is returned.

=back

=head1 CREDITS

Mathieu Gagnon, (c) 2004

This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Text::Template>, L<HTML::Template>

=cut
