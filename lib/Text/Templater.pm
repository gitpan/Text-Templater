package Text::Templater;
use strict;
use warnings;

# And using the power of the enchanted hammer, Thor conjures up a long forgoten event...
# "When something puzzles you, always seek the simplest, most obvious explanation ...no matter HOW impossible it may seem!"

our $VERSION = 1.3;
our @ISA     = ();

sub new();
sub setSource($);
sub setData($);
sub getDataCGI($;);
sub getDataSTH($;);
sub getError();
sub parse();
sub _parse(;$$);
sub _roundNegativeIndex($$;);
sub _getNextNode($;);
sub _makeList($;);
sub _replaceConst($$$;);
sub _getPosEnd($$;);
sub _recordID($$;);
sub _replaceID($;);
sub _fetchAssociatedData($;);
sub _cleanoff($;);
sub hasValue($;);

use constant ERR_NO_SOURCE          => 'Undefined value for template source';
use constant ERR_UNMATCHED_CLOSING  => 'Unmatched closing tag';
use constant WAR_UNMATCHED_OPENING  => 'Unmatched opening tag';
use constant WAR_TAG_NO_NAME        => 'A tag with no name does not make sense';
use constant WAR_MALFORMED_NULLOUT  => 'The nullout property should be yes or no';
use constant WAR_MALFORMED_INDEX    => 'The index property can only have integer value';
use constant WAR_UNDEFINED_LIST     => 'Undefined list element in list parsing';
use constant WAR_MALFORMED_LIST     => 'List attribute malformed';
use constant WAR_UNDEFINED_DATA     => 'Associated data not found';

# Crée un objet templater qui pourra être utilisé après
# avoir specifié la source et les données.
# @param $tagname Nom du tag utilisé dans les templates,
# par défaut la valeur est 'tpl'.
# @return Une instance de la classe Templater.
sub new()
{
  my ($class, $tagname) = (shift, shift);
  my $self = {
    TAGNAME    => "tpl",
    source     => undef,
    data       => undef,
    error      => undef, #Ce champs indique la cause si parse retourne undef.
    warnings   => [],    #Avertissement. Ne cause pas la fin du parsing.
    ids        => {},    #Valeurs enregistrées par la proprietée id.
    idsbck     => {},    #Backup des ids pour les tags ouvert.
    inxbck     => [],    #Stack des derniers index (pour les nested structs).
    index      => 0,     #Index par defaut des valeurs.
    nullout    => "no",  #Valeurs par defaut du parametre nullout.
    };
  $self->{TAGNAME} = $tagname if(hasValue $tagname);
  return bless $self, $class;
}

# Ajuste la source (le template) et retourne le resultat.
# @param $source Le template à parser. (optionel)
# @return Le template à parser.
sub setSource($)
{
  my $self = shift;
  if(@_){
    $self->{source} = shift;
  }
  return $self->{source};
}

# Ajuste les données (les information à mettre dans le template).
# Les données doivent être une référence à un hash dont les
# valeurs sont des référence sur un array {v1 => [0,1]} ou un
# sous hash (une sous structure) (v1 => [{w1 => []}])
# Si un objet CGI ou ST est passe, il est automatiquement convertie.
# @param $data La source des données. (optionel)
# @return La source des données.
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

# Prend un objet CGI et le transforme dans le format
# de données utilisé par Templater.
# @param $cgi L'objet CGI
# @return L'objet CGI convertie, undef en cas d'erreur.
sub getDataCGI($;)
{
  my ($self, $cgi, $data) = (shift, shift, {});
  return undef if(ref $cgi ne 'CGI');

  foreach my $key ($cgi->param){
    $data->{$key} = [$cgi->param($key)];
  }
  return $data;
}

# Prend un objet DBI::st et le transforme dans le format
# de donnees utilise par Templater.
# @param $sth L'objet DBI::st
# @return L'objet DBI::st convertie, undef en cas d'erreur.
sub getDataSTH($;)
{
  my ($self, $sth, $data) = (shift, shift, {});
  my ($key, $ary);
  return undef if(ref $sth ne 'DBI::st');

  while($ary = $sth->fetchrow_hashref()){
    foreach $key (keys %$ary){
      push @{$data->{$key}}, $ary->{$key};
    }
  }
  return $data;
}

# Obtiens l'erreur enregistré.
# Utiliser cette méthode si parse retourne undef
# @return Le message d'erreur ou undef si aucun message.
sub getError()
{
  my $self = shift;
  return $self->{error};
}

# Obtiens la liste des warnings.
# Utiliser cette méthode si parse retourne un résultat incohérant.
# @return La liste des avertissements intervenus.
sub getWarnings()
{
  my $self = shift;
  return @{$self->{warnings}};
}

# Front-end pour _parse.
# C'est cette méthode qui sera appelée par l'utilisateur.
# @return Le résultat, undef en cas d'erreur.
sub parse()
{
  my $self = shift;
  my $source;
  $self->{ids} = {};
  $self->{idsbck} = {};
  $self->{inxbck} = [];
  $self->{error} = undef;
  $self->{warnings} = [];

  $source = $self->_parse($self->{source});
  $source = $self->_replaceID($source);
  $source = $self->_cleanoff($source);
  
  return (defined $self->{error}) ? undef : $source;
}

# Effectue un remplacement des tags <tpl> de la source
# et retourne le resultat.
# @param $source Source des données à parser.
# @param $index Index à prendre par défault. (optionel)
# @return Le résultat, undef en cas d'erreur.
sub _parse(;$$)
{
  my ($self, $source) = (shift, shift);
  my $index = hasValue($_[0]) ? shift : $self->{index};
  my $val = '';
  my ($i, $data, %node);
  if(!defined $source){
    $self->{error} = ERR_NO_SOURCE;
    return undef;
  }
  return $source if(defined $self->{error});

  while((%node = $self->_getNextNode($source)) && hasValue $node{tag} && !defined $self->{error}){
    if(hasValue $node{inner}){
      $node{index} = $self->{index} if(!hasValue $node{index});
      $node{nullout} = $self->{nullout} if(!hasValue $node{nullout});

      #enregistrement de l'index avant la boucle pour connaitre
      #la position de l'index dans les donnees plus subséquente.
      push @{$self->{inxbck}}, {name => $node{key}, index => $node{index}};
      $data = $self->_fetchAssociatedData(\%node);
      next if(!defined $data);
      $i = $self->_roundNegativeIndex($node{index}, scalar @$data);

      # !defined $data || $i < scalar @$data  ..  what the fuck is that??
      for(my $inc_list = 0; $i < scalar @$data; $i++, $self->{inxbck}[-1]->{index}++){
        $self->_recordID($node{id}, $$data[$i]);
        if($node{nullout} eq "no" || hasValue $$data[$i]){
          $val .= $self->_parse($self->_replaceConst($node{inner}, $node{list}, $inc_list), $i);
          $inc_list++;
        }
        $val = $self->_replaceID($val);
      }
      pop @{$self->{inxbck}};
    }
    else{
      $node{index} = $index if(!hasValue $node{index});
      $data = $self->_fetchAssociatedData(\%node);
      next if(!defined $data);

      $i = $self->_roundNegativeIndex($node{index}, scalar @$data);
      $val = $$data[$i];
      if(hasValue $node{id}){
        $self->_recordID($node{id}, $val);
        $val = '';   #La valeur pour un tag id ne doit pas etre imprimer.
      }
    }
  } continue{
	  $val = '' if(!defined $val);
    $source =~ s/\Q$node{tag}\E/$val/;
    $val = '';
  }

  return $source;
}

# Prend un index et la limite possible et s'assure
# que l'index ne dépasse pas la limite de zéro si la valeur est négative.
# Par example, une limite de -10 et un index de -12 donne 0.
# @param $i Index
# @param $length Limit
# @return Valeur respectant la limite.
sub _roundNegativeIndex($$;){
  my ($self, $i, $length) = (shift, shift, shift);
  $i = 0 if(!defined $i);
  $length = 0 if(!defined $length);
  return ($i < 0) ? (-$i > $length) ? 0 : $i + $length : $i;
}

# Retourne le prochain tag <tpl> trouvé. Le tag est représenté
# dans un hash contenant les clefs suivante :
#   tag, inner, id, key, nullout, index et list.
# @param $source Template sur lequel rechercher le prochain tag.
# @return Un hash représentant le tag, un hash vide sinon.
sub _getNextNode($;)
{
  my ($self, $source) = (shift, shift);
  my ($pos, $posend, $tag, $tagend, @list, %res);
  $source =~ m/(<\Q$self->{TAGNAME}\E[^>]*?>)/gs;
  ($res{tag}, $tag, $pos) = ($1, $1, pos($source));
  return () if(!hasValue $res{tag});  #aucun tag trouvé

  if($tag !~ m/\/>$/){   #Tag avec du contenu..
    ($posend, $tagend) = $self->_getPosEnd($source, pos($source));
    return () if(!defined $posend);   #Une erreur est servenue avec getPosEnd ..

    $pos = $pos - length $res{tag};
    $res{tag} = $res{inner} = substr($source, $pos, $posend - $pos);
    $res{inner} =~ s/^\Q$tag\E(.*)\Q$tagend\E$/$1/s;
  }

  $res{id}      = $1 if($res{tag} =~ m/^<[^>]*?id="(.*?)"[^>]*?>/);
  $res{key}     = $1 if($res{tag} =~ m/^<[^>]*?name="(.*?)"[^>]*?>/);
  $res{nullout} = $1 if($res{tag} =~ m/^<[^>]*?nullout="(.*?)"[^>]*?>/);
  $res{index}   = $1 if($res{tag} =~ m/^<[^>]*?index="(.*?)"[^>]*?>/);
  push(@list, $1) while($tag =~ m/list="(.*?)"/g);
  %{$res{list}} = $self->_makeList(@list);

	push @{$self->{warnings}}, WAR_TAG_NO_NAME
		if(!hasValue $res{key});
	push @{$self->{warnings}}, WAR_MALFORMED_NULLOUT
		if(defined $res{nullout} && $res{nullout} ne 'yes' && $res{nullout} ne 'no');
	if(defined $res{index} && $res{index} !~ m/^-?\d+$/){
		push @{$self->{warnings}}, WAR_MALFORMED_INDEX;
		$res{index} = undef;
	}

  return %res;
}

# Effectue le parsing de la propriété 'list'. Si une constante est
# définie plus d'une fois, le resultat est celui de la derniere definition.
# @param $src Liste des propriétées 'list' sous forme "CONST:v1,v2...".
# @return Un hash contenant avec une liste comme valeur.
# En cas d'erreur, undef est retourne.
sub _makeList($;)
{
  my ($self, @src, %res) = (shift, @_, ());
  my ($const, $vals, $list);

  foreach $list (@src){
    if(!hasValue $list){
      push @{$self->{warnings}}, WAR_UNDEFINED_LIST;
      next;
    }
    if($list !~ m/(\w*?):(.*)/){
      push @{$self->{warnings}}, WAR_MALFORMED_LIST;
      next;
    }
    
    ($const, $vals) = ($1, $2);
    $vals =~ s/\\,/\0/; $vals =~ s/\\(.)/$1/;
    $res{$const} = [split(/,/, $vals)];
    map { s/\0/,/g; s/^\s*//g; s/\s*$//g; } @{$res{$const}};  #mmmm...
  }

  return %res;
}


# Effectue un remplacement des constantes définie par la
# propriété 'list' après avoir été parsé par _makeList.
# Les valeurs tournent en rond (v1,v2,v3), index 5 == v2
# @param $src Source sur laquel effectuer le remplacement.
# @param $const Liste des constantes tel que retourné par _makeList
# @param $index Index actuel, ne pas confondre avec la propriété 'index'
# @return la source avec les valeurs remplacés.
sub _replaceConst($$$;)
{
  my ($self, $src, $const, $index) = @_;
  my ($inx, $start, $end, $tmp, $tmp2, $tag, $pos);
  return $src if(scalar keys %$const == 0);

  foreach my $key (keys %$const){
	  #L'index doit tourner en rond ..
    $inx = ($index > scalar @{$const->{$key}}-1) ?
      $index % scalar @{$const->{$key}} : $index;

    #La subtilité est que le remplacement ne doit pas ce 
    #faire dans les sous-tags.
    for($start = $end = 0; $start < length $src; $start = $end, $tag = ''){
      pos($src) = $start;
      if($src =~ m/(<\Q$self->{TAGNAME}\E[^>]*?>)/gs){
        ($tag, $pos) = ($1, pos($src));
        $end = $pos - length $tag;
      }
      else{
        $end = length $src;
      }

      $tmp = $tmp2 = substr($src, $start, $end);
      $tmp =~ s/\Q$key\E/$const->{$key}->[$inx]/g;
      $src =~ s/\Q$tmp2\E/$tmp/;

      ($end, $tmp) = ($tag =~ m/\/>$/) ?
        ($end + length $tag, '') : $self->_getPosEnd($src, $pos)
          if(hasValue $tag);
    }
  }
  return $src;
}

# Prend la source de donnée et retourne la position du
# tag fermant correspondant en prenant pour acquis qu'un
# tag ouvert a bel et bien trouvé.
# Si il ne trouve pas la fin, la fin est length $src
# @param $src Tag à recherché
# @param $start Position de début
# @return Retourne la position et le tag
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

  if($count != 0){
    $self->{error} = ERR_UNMATCHED_CLOSING;
    return (length $src, $src);
  }
  return ($pos, $tag);
}

# Effectue un enregistrement d'un id et de sa valeur
# $self->ids et $self->idsbck sont utilisé.
# La première valeur est toujours gardé dans idsbck,
# Les valeurs suivants prennent la place dans ids.
# @param $id clef
# @param $value valeur
sub _recordID($$;)
{
  my ($self, $id, $value) = (@_);
  return if(!hasValue $id);
  $value = '' if(!defined $value);

  if(!hasValue $self->{ids}->{$id}){
    $self->{ids}->{$id} = $value;
  }
  else{
    if(!hasValue $self->{idsbck}->{$id}){
      $self->{idsbck}->{$id} = $self->{ids}->{$id};
    }
    $self->{ids}->{$id} = $value;
  }
}

# Remplace chque id enregistrer par la valeur binder
# dans la source. Lorsque replaceID est termine, le
# id de backup est recopier dans le id.
# @param $src Source dans le remplacement
# @return La source après le remplacement
sub _replaceID($;)
{
  my ($self, $src) = (@_);
  return undef if(!defined $src);

  foreach my $key (keys %{$self->{ids}}){
    $src =~ s/(<[^>]*?=")#\Q$key\E("[^>]*?>)/$1$self->{ids}->{$key}$2/g;
    if(hasValue $self->{idsbck}->{$key}){
      $self->{ids}->{$key} = $self->{idsbck}->{$key};
      $self->{idsbck}->{$key} = undef;
    }
  }
  return $src;
}

# Va chercher les données associé au nom en tenant compte de sont nom. 
#	Les index par défault dont gardé en stack. Par example, "hashref.nestedhashref", 
# hashref prend l'index en backup s'il est présent.
# @param $node Référence sur le noeud.
# @return Une référence sur le array ou undef si non trouvé.
sub _fetchAssociatedData($;)
{
  my ($self, $node) = (@_);
  return undef if(!defined $node || !defined $node->{key});

  my @selectors = split(/\./, $node->{key});
  my @Kselectors = ();
  my $data = $self->{data};
  my ($bck, $inx);
  my $seq = 1;   #si le nom est dans la sequence de boucle (a <=> a.b)

  for(my $i = 0; defined $data && $i < scalar @selectors -1; $i++){
    $bck = $self->{inxbck}[$i];
    @Kselectors = split(/\./, $bck->{name}) if(defined $bck);

    #si il y a plus de nom de backup (a.b.c) compare au nombre d'element backuper,
    #il faut consider l'index comme etant associe au dernier nom (c).
    if($seq && defined $Kselectors[$i] && $selectors[$i] eq $Kselectors[$i] && $i == scalar @Kselectors -1){
      $inx = $bck->{index};
    }
    else{
      $inx = $self->{index};
      $seq = 0;
    }
    $data = $data->{$selectors[$i]};
    last if(!defined $data);
    $data = $$data[$inx];
  }

  if(!defined $data || !defined ($data = $data->{$selectors[-1]})){
    push @{$self->{warnings}}, WAR_UNDEFINED_DATA;
    return undef;
  }

  return $data;
}

# Effectue le nettoyage de tous les tags tpl.
# La méthode ne devrais rien trouvé et donne un warning si c'est le cas.
# @param $source Source à nettoyer
sub _cleanoff($;)
{
  my ($self, $source) = (shift, shift);
  if(defined $source && $source =~ m/<\/\Q$self->{TAGNAME}\E[^>]*?>/){
    $source =~ s/<\/\Q$self->{TAGNAME}\E[^>]*?>//gs;
      push @{$self->{warnings}}, WAR_UNMATCHED_OPENING;
  }
  return $source;
}

# Simple méthode utilitaire pour déterminer si une variable
# contient une valeur ou non.
sub hasValue($;)
{
  my $value = shift;
  return (defined($value) && $value ne '');
}


1;
__END__


=pod

=head1 NAME

Templater - A template engine.

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
    nested => 
      [
        {lang => ['fr'], numeric => ['un', 'deux', 'trois', 'quatre']},
        {lang => ['en'], numeric => ['one', 'two', 'three', 'four']}
      ]
    });
  #Or use existing objects.
  $tpl->setData($cgi);
  $tpl->setData($sth);
  
  #Get the result.
  $result = $tpl->parse() || die $tpl->getError();
   
  #if you get weird stuff,
  #check for $tpl->getWarnings();

=head1 ABSTRACT

The objective of the Templater object is to separate data manipulation from
it's representation while keeping out logic as much as possible from the representation side.

=head1 DESCRIPTION

Templater receive the template and the data to be binded in the template.
Then using the parse method, it return the result.

One tag and 5 properties are used in a xmlish way to describe data in the template.
Since the object use an xml tag, you can use it in your xml files while keeping them 
well-formedness and valid.

<tpl id="x" name="key" index="0" nullout="no" list="CONST:1,2,3..." />


=head2 Tag properties

=over

=item id="unique"

  You can specify the id of an element to make late references to it.
  This can be used for not breaking the well-formedness of a xml
  document. You could write <tpl id="myvalue" name="nom" />
  <othertag value="#myvalue" /> instead of
  <other-tag value="<tpl name="nom" />" />.
  A tag with the id specified will not print his result, only
  record it for late references. Note that the second alternalive 
  will work as well.

=item name="name"

  You can bind a specific data value to a tag using it's hash key.
  A tag without a name does not make sense.
  In the synopsis; <tpl name="color" /> eqals red.
  If you have nested structures, you can use the notation a.b
  <tpl name="nested.lang" /> equals fr.

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

=item getError

Returns the error that was recorded during the last parsing.
This method should return undef if parse return a value and
the cause of the error if parse says undef.

=item getWarnings

Returns the list of the warnings that occurned in the last 
parsing. This is the first place to look if you think you have 
weird or unexpected results.

=back

=head1 CREDITS

Mathieu Gagnon

This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
