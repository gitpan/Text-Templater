package Text::Templater;
use strict;
use warnings;

our $VERSION = 1.2;
our @ISA     = ();

sub new();
sub setSource($);
sub setData($);
sub getDataCGI($;);
sub getDataSTH($;);
sub getSourceFILE($);
sub parse();
sub _parse(;$$);
sub _roundNegativeIndex($$;);
sub _getNextNode($;);
sub _makeList($;);
sub _replaceConst($$$;);
sub _getPosEnd($$;);
sub _recordID($$;);
sub _replaceID($;);

#Constructeur de l'objet.
#Il est possible de lui passer en parametre, un nom specifique
#de tag à utiliser pendant la duree de l'objet.
sub new()
{
  my ($class, $tagname) = (shift, shift);
  my $self = {
    TAGNAME    => "tpl",
    source     => '',
    data       => {},
    ids        => {},
    idsbck     => {},
    index      => 0,    #Index par defaut des valeurs.
    nullout    => "no", #Valeurs par defaut du parametre nullout.
    };
  $self->{TAGNAME} = $tagname if(defined($tagname));
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

#Front-end pour _parse
#C'est cette méthode qui sera appelé par l'utilisateur.
sub parse()
{
  my ($self, $source) = (shift, '');
  $source = $self->_parse();
  $source = $self->_replaceID($source);
  $self->{ids} = {};
  $self->{idsbck} = {};
  return $source;
}

#Effectue un remplacement des tags <tpl> à l'interieur
#de la source et retourne le resultat.
#Les parametre optionel sont les suivant: la source et l'index.
#Si les parametre ne sont pas specifier, les valeurs par defaut
#sont prisent pour acquise.
sub _parse(;$$)
{
  my ($self, $val, %node) = (shift, '', ());
  my $source  = defined($_[0]) ? shift : $self->{source};
  my $index   = defined($_[0]) ? shift : $self->{index};
  my ($i, $j);  #value index et constant index
  return $source if(!defined($source) || $source eq '');
  return $source if(!defined($self->{data}));

  while((%node = $self->_getNextNode($source)) && defined($node{tag})){
    if(!defined($node{key}) || !defined($self->{data}->{$node{key}})){
      $val = ''; 
    }
    elsif(!defined($node{inner})){
      $node{index} = $index if(!defined($node{index}));
      $i = $self->_roundNegativeIndex($node{index}, scalar @{$self->{data}->{$node{key}}});
      $val = $self->{data}->{$node{key}}[$i];
      $self->_recordID($node{id}, $val);
    }
    elsif(defined($self->{data}->{$node{key}})){
      $node{index} = $self->{index} if(!defined($node{index}));
      $node{nullout} = $self->{nullout} if(!defined($node{nullout}));
      $i = $self->_roundNegativeIndex($node{index}, scalar @{$self->{data}->{$node{key}}});
      $j = 0;
      for(; !defined $self->{data}->{$node{key}} || $i < scalar @{$self->{data}->{$node{key}}}; $i++){
        $self->_recordID($node{id}, $self->{data}->{$node{key}}[$i]);
        if($node{nullout} eq "no" || (defined($self->{data}->{$node{key}}[$i]) && $self->{data}->{$node{key}}[$i] ne "")){
          $val .= $self->_parse($self->_replaceConst($node{inner}, $node{list}, $j), $i);
          $j++;
        }
        $val = $self->_replaceID($val);
      }
    }
  } continue{
    $val = '' if(!defined($val));
    $source =~ s/\Q$node{tag}\E/$val/;
    $val = '';
  }
  return $source;
}

#Round a int inside the array limit.
sub _roundNegativeIndex($$;){
  my ($self, $i, $length) = (shift, shift, shift);
  return ($i < 0) ? (-$i > $length) ? 0 : $i + $length : $i;
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

  $res{id}      = $1 if($res{tag} =~ m/^<[^>]*?id="(.*?)"[^>]*?>/);
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
    if($list =~ m/(\w*?):(.*)/){
      ($const, $vals) = ($1, $2);
      $vals =~ s/\\,/\0/; $vals =~ s/\\(.)/$1/;
      $res{$const} = [split(/,/, $vals)];
      map { s/\0/,/g; s/^\s*//g; s/\s*$//g; } @{$res{$const}};
    }
    else{
      warn "list attribute malformed : $list";
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
          if(defined($tag) && $tag ne '');
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

  die "Unmatched closing tag for :\n$src" if($count != 0);
  return ($pos, $tag);
}

#Effectue un enregistrement à travers $self->ids et 
#$self->idsbck.
sub _recordID($$;)
{
  my ($self, $id, $value) = (@_);
  return if(!defined($id));
  $value = '' if(!defined($value));

  if(!defined($self->{ids}->{$id})){
    $self->{ids}->{$id} = $value;
  }
  else{
    if(!defined($self->{idsbck}->{$id})){
      $self->{idsbck}->{$id} = $self->{ids}->{$id};
    }
    $self->{ids}->{$id} = $value;
  }
}

#Replace every id that have been recorded with binded 
#value in the src. After replaceID is done, the backup 
#ids are copied back in the ids.
sub _replaceID($;)
{
  my ($self, $src) = (@_);
  foreach my $key (keys %{$self->{ids}}){
    $src =~ s/(<[^>]*?=")#\Q$key\E("[^>]*?>)/$1$self->{ids}->{$key}$2/;
    if(defined($self->{idsbck}->{$key})){
      $self->{ids}->{$key} = $self->{idsbck}->{$key};
      $self->{idsbck}->{$key} = undef;
    }
  }
  return $src;
}


1;
__END__


=pod

=head1 NAME

Templater - Parse data inside a template.

=head1 SYNOPSIS

   #!/usr/bin/perl
   use Text::Templater;

   my $tpl = new Text::Templater($tagname); 
   #Default tagname is "tpl"

   $tpl->setSource($some_template_text);

   #Set the data source...
   $tpl->setData({                
      name => ['bob', undef, 'daniel'],
      color => ['red', 'green', 'blue'],
      });
   #Or use existing objects.
   $tpl->setData($cgi);           
   $tpl->setData($sth);

   print $tpl->parse();  #Get the result.


=head1 ABSTRACT

The objective of the Templater object is to separate data manipulation from
it's representation while keeping out logic as much as possible from the representation side.

=head1 DESCRIPTION

Templater receive the template and the data to be binded in the template.
Then using the parse method, it return the result.

One tag and 5 properties are defined in a xmlish way to describe data in the template.
Internaly regular expressions are used instead of a xml parser, so it can be used with any kind of text files.
Still, you can also use it in your xml while keeping their well-formedness and valitiy of the document.

<tpl id="x" name="key" index="0" nullout="no" list="CONST:1,2,3..." />


=head2 Tag properties

=over

=item id="unique"
  
  You can specify the id of an element to make late reference to it.
  This can be used for not breaking the well-formedness of a xml
  document. You could write <tpl id="myvalue" name="nom" /> 
  <othertag value="#myvalue" /> instead of 
  <other-tag value="<tpl name="nom" />" />. 
  Note that the second alternalive will work as well.

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
  is discarded. no is taken by default. In the synopsis: 
  <tpl name="name" nullout="yes">hi</tpl> equals nothing.

=item list="CONST:1,2,3,..."

  Defines a specific constant "CONST" into the tag inner source.
  The value of CONST will alternativly be 1,2,3,1,2,etc
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
You can specify the tag name to be used in templates.
No verification of the validity of name is made.

=item setSource

If a scalar is passed, it is set to be the template.
The source of the object is returned.

=item setData

If a value is passed, it is set to be the data to bind.
CGI and STH objects can be passed.
The data of the object is returned.

=item parse

Takes the template and parse the data inside using the
templater tags. The parsed template is returned.

=back


=head1 CREDITS

Mathieu Gagnon, (c) 2005

This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
