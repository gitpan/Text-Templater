# Text::Templater - A template engine
#
# Copyright (C) 2003, 2004 by Mathieu Gagnon
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package Text::Templater;
use strict;
use warnings;

# And using the power of the enchanted hammer, Thor conjures up a long forgoten event...
# "When something puzzles you, always seek the simplest, most obvious explanation ...no matter HOW impossible it may seem!"

our $VERSION = '1.4';
our @ISA     = ();

sub new();
sub _init();
sub setSource($);
sub setData($);
sub getError();
sub getErrorNo();
sub getWarnings();
sub getWarningsNo();
sub _posInFile();
sub _setError($;);
sub _pushWarning($;);
sub parse();
sub _parse($;$);
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

use constant ERR_NO_SOURCE           => {NO => 201, MSG => 'Undefined value for template source'};
use constant ERR_UNMATCHED_CLOSING   => {NO => 202, MSG => 'Unmatched closing tag'};
use constant ERR_MALFORMED_STRUCTURE => {NO => 203, MSG => 'Malformed data structure'};
use constant WAR_UNMATCHED_OPENING   => {NO => 601, MSG => 'Unmatched opening tag'};
use constant WAR_TAG_NO_NAME         => {NO => 602, MSG => 'A tag with no name does not make sense'};
use constant WAR_MALFORMED_NULLOUT   => {NO => 603, MSG => 'The nullout property should be yes or no'};
use constant WAR_MALFORMED_INDEX     => {NO => 604, MSG => 'The index property can only have integer value'};
use constant WAR_UNDEFINED_LIST      => {NO => 605, MSG => 'Undefined list element in list parsing'};
use constant WAR_MALFORMED_LIST      => {NO => 606, MSG => 'List attribute malformed'};
use constant WAR_UNDEFINED_DATA      => {NO => 607, MSG => 'Associated data not found'};

use constant STR_LN => ' at ln ';
use constant STR_CO => ', co ';


# Crée un objet templater qui pourra être utilisé après
# avoir specifié la source et les données.
sub new()
{
  my ($class, $tagname) = (shift, shift);
  my $self = {
    TAGNAME    => 'tpl',
    source     => undef,
    data       => undef,
    index      => 0,     #Index par defaut des valeurs.
    nullout    => 'no',  #Valeurs par defaut du parametre nullout.
    };
  $self->{TAGNAME} = $tagname if(hasValue $tagname);

  bless $self, $class;
  $self->_init();

  return $self;
}

# Initialise proprement l'objet
sub _init()
{
  my $self = shift;

  $self->{error} = {'no' => undef, 'msg' => undef};  #Ce champs indique la cause si parse retourne undef.
  $self->{warnings} = {'no' => [], 'msg' => []};     #Avertissement. Ne cause pas la fin du parsing.
  $self->{ids} = {};           #Valeurs enregistrées par la proprietée id.
  $self->{idsbck} = {};        #Backup des ids pour les tags ouvert.
  $self->{inxbck} = [];        #Stack des derniers index (pour les nested structs).
  $self->{posi} = [0];         #Variables utilisé pour le calculs de la ligne dans msg d'err.
  $self->{posg} = [0];
  $self->{lentag} = [0];
}

# Ajuste la source (le template) et retourne le resultat.
# @param $source Le template à parser. (optionel)
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
# valeurs sont des référence sur des array {v1 => [0,1]} ou un
# sous hash (une autre structure) (v1 => [{w1 => []}])
# @param $data La source des données. (optionel)
sub setData($)
{
  my $self = shift;
  if(@_){
    $self->{data} = shift;
  }
  return $self->{data};
}

# Obtiens l'erreur enregistré.
# Utiliser cette méthode si parse retourne undef
# @return Le message d'erreur ou undef si aucun message.
sub getError()
{
  my $self = shift;
  return $self->{error}->{'msg'};
}

# Obtiens le numéro d'erreur enregistré.
# @return Le numéro d'erreur ou undef si aucune erreur.
sub getErrorNo()
{
  my $self = shift;
  return $self->{error}->{'no'};
}

# Obtiens la liste des warnings.
sub getWarnings()
{
  my $self = shift;
  return @{$self->{warnings}->{'msg'}};
}

# Obtiens la liste des numéros de warnings.
sub getWarningsNo()
{
  my $self = shift;
  return @{$self->{warnings}->{'no'}};
}

# Formate la position de l'erreur pour être affichée
# en ln n co n.
sub _posInFile()
{
  my $self = shift;
  my $pos = 0;
  foreach $_ (@{$self->{posi}}){ $pos += $_; }
  foreach $_ (@{$self->{posg}}){ $pos += $_; }
  foreach $_ (@{$self->{lentag}}){ $pos += $_; }

  my $source = defined $self->{source} ? $self->{source} : '';
  my $region = substr $source, 0, $pos;
  my $line = () = $region =~ m/(\n)/gs;
  my $posline = rindex $region, "\n";

  return STR_LN . ($line+1) . STR_CO . (length($region) - $posline);
}

# Enregistre une erreur
sub _setError($;)
{
  my ($self, $err) = @_;
  $self->{error}->{'no'} = $err->{'NO'};
  $self->{error}->{'msg'} = 'Error: ' . $err->{'MSG'} . $self->_posInFile();
}

# Ajoute un warning à la liste.
sub _pushWarning($;)
{
  my ($self, $err) = @_;
  my $msg = 'Warning: ' . $err->{'MSG'} . $self->_posInFile();

  if(map { $_ eq $msg } @{$self->{warnings}->{'msg'}}){
    ;
  }else{
    push @{$self->{warnings}->{'no'}}, $err->{'NO'};
    push @{$self->{warnings}->{'msg'}}, $msg;
  }
}

# Front-end pour _parse.
# C'est cette méthode qui sera appelée par l'utilisateur.
# @return Le résultat, undef en cas d'erreur.
sub parse()
{
  my $self = shift;
  my $source;
  $self->_init();

  $source = $self->_parse($self->{source});
  $source = $self->_replaceID($source);
  $source = $self->_cleanoff($source);
  
  return (defined $self->{error}->{'no'}) ? undef : $source;
}

# Effectue un remplacement des tags <tpl> de la source
# et retourne le resultat.
# @param $source Source des données à parser.
# @param $index Index à prendre par défault. (optionel)
sub _parse($;$)
{
  my ($self, $source) = (shift, shift);
  my $index = hasValue($_[0]) ? shift : $self->{index};
  my $replace = '';       #La valeur de remplacement
  my ($i, $data, %node);  #for i; Data associé au remplacement; node (object)
  if(!defined $source){
    $self->_setError(ERR_NO_SOURCE);
    return undef;
  }
  return $source if(defined $self->{error}->{'no'});


  while((%node = $self->_getNextNode($source)) && hasValue $node{tag} && !defined $self->{error}->{'no'}){

    if(defined $node{inner}){
      $node{index} = $self->{index} if(!hasValue $node{index});
      $node{nullout} = $self->{nullout} if(!hasValue $node{nullout});

      #enregistrement de l'index avant la boucle pour connaitre
      #la position de l'index dans les donnees plus subséquente.
      push @{$self->{inxbck}}, {name => $node{key}, index => $node{index}};
      $data = $self->_fetchAssociatedData(\%node);
      next if(!defined $data);
      
      push @{$self->{posi}}, 0;  #incrémente le buffer
      push @{$self->{posg}}, 0;
      
      $i = $self->_roundNegativeIndex($node{index}, scalar @$data);

      for(my $inc_list = 0; $i < scalar @$data; $i++, $self->{inxbck}[-1]->{index}++){
        $self->{posi}[-1] = 0;   #Remise à 0 pour ne pas interagire avec le reste
        $self->{posg}[-1] = 0;

        $self->_recordID($node{id}, $$data[$i]);
        if($node{nullout} eq "no" || hasValue $$data[$i]){
          $replace .= $self->_parse($self->_replaceConst($node{inner}, $node{list}, $inc_list), $i);
          $inc_list++;
        }
        $replace = $self->_replaceID($replace);
      }
      pop @{$self->{posi}};      #décrémente le buffer
      pop @{$self->{posg}};      #ce n'était que temporaire pour ne pas intéragir avec les autres valeurs.
      pop @{$self->{lentag}};
      pop @{$self->{inxbck}};
    }
    else{
      $node{index} = $index if(!hasValue $node{index});
      $data = $self->_fetchAssociatedData(\%node);
      $data = [] if(!defined $data);

      $i = $self->_roundNegativeIndex($node{index}, scalar @$data);
      $replace = $$data[$i];
      if(hasValue $node{id}){
        $self->_recordID($node{id}, $replace);
        $replace = '';   #La valeur pour un tag id ne doit pas etre imprimer.
      }
    }
  } continue{
	  $replace = '' if(!defined $replace);
	  $self->{posi}[-1] += length($node{tag}) - length($replace);
    $source =~ s/\Q$node{tag}\E/$replace/;
    $replace = '';
  }

  return $source;
}

# Prend un index et la limite possible et s'assure
# que l'index ne dépasse pas la limite de zéro si la valeur est négative.
# Par example, une limite de -10 et un index de -12 donne 0.
# @param $i Index
# @param $length Limit
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
  $self->{posg}[-1] = $pos - length $res{tag};

  #Test si des tags ferme existe avant notre ouvert
  my $test = substr($source, 0, $self->{posg}[-1]);
  while($test =~ m/(<\/\Q$self->{TAGNAME}\E[^>]*?>)/g){
    $self->_pushWarning(WAR_UNMATCHED_OPENING);
  }
  
  if($tag !~ m/\/>$/){   #Tag avec du contenu..
    push @{$self->{lentag}}, length $tag;

    ($posend, $tagend) = $self->_getPosEnd($source, pos($source));
    return () if(!defined $posend);   #Une erreur est servenue avec getPosEnd ..

    $pos = $pos - length $res{tag};
    $res{tag} = $res{inner} = substr($source, $pos, $posend - $pos);
    $res{inner} =~ s/^\Q$tag\E(.*)\Q$tagend\E$/$1/s;
  }

  $res{id}      = $1 if($res{tag} =~ m/^<[^>]*?id="(.*?)"[^>]*?>/);
  $res{key}     = $1 if($res{tag} =~ m/^<[^>]*?name="(.*?)"[^>]*?>/);
  $res{nullout} = $1 if($res{tag} =~ m/^<[^>]*?nullout="(.*?)"[^>]*?>/);
  if(defined $res{key} && $res{key} =~ m/^(.*)\[(.*)\]$/){
    $res{key}   = $1;
    $res{index} = $2;
  }
  else{
    #Cette ligne est gardé simplement pour compatiblité avec les ancienne versions.
    $res{index}   = $1 if($res{tag} =~ m/^<[^>]*?index="(.*?)"[^>]*?>/);
  }

  push(@list, $1) while($tag =~ m/list="(.*?)"/g);
  %{$res{list}} = $self->_makeList(@list);

  if(!hasValue $res{key}){
    $self->_pushWarning(WAR_TAG_NO_NAME);
  }

	$self->_pushWarning(WAR_MALFORMED_NULLOUT)
	  if(defined $res{nullout} && $res{nullout} ne 'yes' && $res{nullout} ne 'no');

	if(defined $res{index} && $res{index} !~ m/^-?\d+$/){
  	$self->_pushWarning(WAR_MALFORMED_INDEX);
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
      $self->_pushWarning(WAR_UNDEFINED_LIST);
      next;
    }
    if($list !~ m/(\w*?):(.*)/){
      $self->_pushWarning(WAR_MALFORMED_LIST);
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
    if($tag !~ m/\/>$/){
      if($tag =~ m/^<\//){
        --$count;
      }
      else{
        ++$count;
      }
    }
  }

  if($count > 0){
    $self->_setError(ERR_UNMATCHED_CLOSING);
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
# hashref prend l'index en backup s'il est présent et non spécifié (hashref[i]).
# @param $key Nom de la clef.
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

  for(my $i = 0; $i < scalar @selectors -1; $i++){
    #vérifier si un index par défaut est spécifié.
    if($selectors[$i] =~ m/^(.*)\[(\d)\]$/){
      $selectors[$i] = $1;
      $inx = $2;
    }
    else{
      #sinon aller chercher l'index qu'on as besoin
      $bck = $self->{inxbck}[$i];
      @Kselectors = split(/\./, $bck->{name}) if(defined $bck);

      #si il y a plus de nom de backup (a.b.c) compare au nombre d'elements backuper,
      #il faut consider l'index comme etant associe au dernier nom (c).
      if($seq && defined $Kselectors[$i] && $selectors[$i] eq $Kselectors[$i] && $i == scalar @Kselectors -1){
        $inx = $bck->{index};
      }
      else{
        $inx = $self->{index};
        $seq = 0;
      }
    }

    $data = $data->{$selectors[$i]};
    last if(!defined $data);
    $data = $$data[$inx];
    last if(!defined $data);

    if(ref $data ne 'HASH'){
      $self->_setError(ERR_MALFORMED_STRUCTURE);
      return undef;
    }
  }

  if(!defined $data || !defined ($data = $data->{$selectors[-1]})){
    $self->_pushWarning(WAR_UNDEFINED_DATA);
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
    $self->_pushWarning(WAR_UNMATCHED_OPENING);
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

Text::Templater - A template engine

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

  #Get the result.
  $result = $tpl->parse() || die $tpl->getError();

  #if you get weird stuff,
  #check the $tpl->getWarnings();

=head1 ABSTRACT

The objective of the Templater object is to separate data manipulation from
it's representation while keeping out logic as much as possible from the representation side.

=head1 DESCRIPTION

Templater receive the template and the data to be binded in the template.
Then using the parse method, it return the result.

One tag and 4 properties are used in a xmlish way to describe data in the template.
Since the object use an xml tag, you can use it in your xml files while keeping them
well-formed and valid.

<tpl id="x" name="key" nullout="no" list="CONST:1,2,3..." />


=head2 Tag properties

=over

=item id="unique"

  You can specify the id of an element to make late references to it.
  This can be used for not breaking the well-formedness of a xml
  document. You could write <tpl id="myvalue" name="nom" />
  <othertag value="#myvalue" /> instead of
  <other-tag value="<tpl name="nom" />" />.
  A tag with the id specified will not print his result, only
  record it for late references. 
  Note that the second alternalive will work as well.

=item name="name"

  You can bind a specific data value to a tag using it's hash key.
  A tag without a name does not make sense.
  In the synopsis; <tpl name="color" /> eqals red.
  Name can be joined by a point to represent nested structure.
  Also, the index property have been moved into the name so it's possible
  to index any element of a nested structure. "element[i]",
  "element[i].nested[j]", "element.nested[i]".

=item nullout="yes|no"

  If the binded value is undef or '', all the expression
  is discarded. no is taken by default. In the synopsis:
  <tpl name="name[1]" nullout="yes">hi</tpl> equals nothing.

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

=item setSource

If a scalar is passed, it is set to be the template.
The source of the object is returned.

=item setData

If a value is passed, it is set to be the data to bind.
The data of the object is returned.

=item parse

Takes the template and parse the data inside using the
templater tags. The parsed template is returned.

=item getError

Returns the error that was recorded during the last parsing.
This method should return undef if parse return a value and
the cause of the error if parse says undef.

=item getErrorNo

Returns the error number that was recorded during the last
parsing.

=item getWarnings

Returns the list of the warnings that occurned in the last
parsing. This is the first place to look if you think you have
weird or unexpected results.

=item getWarningsNo

Returns the list of warnings number that occured during the
last parsing.

=back

=head1 AUTHOR

Mathieu Gagnon <gagnonm@cpan.org>

This package is free software.

=cut
