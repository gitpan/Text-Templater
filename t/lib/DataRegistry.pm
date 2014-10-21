package DataRegistry;
use strict;
use warnings;

our $VERSION = 1.0;
our @ISA     = ();

sub new();
sub get($;);
sub set($$;);
sub length($;);
sub push($$;);
sub pop($;);
sub shift($;);
sub unshift($$;);
sub merge($;);
sub _lastid($;);
sub _fetcharray($$;);

# Cr�e une instance de DataHolder
sub new()
{
  my $class = CORE::shift;
  my $self = {
    data       => {}  #Conteneur de donn�es.
    };
  
  return bless $self, $class;
}

# Recherche une valeur selon le pattern donn�e.
# nom suivit d'un s�lecteur optionel ([i]) suivit d'un point
# pour acc�der � une structure imbriqu�.
# @param path nom[i].subname[i]
# @return la valeur associ�, undef si aucune
sub get($;)
{
  my ($self, $path) = @_;
  my $index = $self->_lastid($path);
  my $values = $self->_fetcharray($path, 0);
  return $$values[$index];
}

# Ajuste une valeur dans la structure selon le pattern donn�e.
# @param path nom[i].subname[i]
# @return la valeur cr�e, undef en cas d'erreur
sub set($$;)
{
  my ($self, $path, $value) = @_;
  return undef if(ref $value eq 'HASH');
  my $index = $self->_lastid($path);
  my $values = $self->_fetcharray($path, 1);
  $$values[$index] = $value;
  return $$values[$index];
}

# Retourne le nombre de valeurs pour la clef
# @path path nom[i].subname[i]
sub length($;)
{
  my ($self, $path) = @_;
  my $index = $self->_lastid($path);
  my $values = $self->_fetcharray($path, 1);
  return scalar @$values;
}

# Push une valeur dans la structure.
sub push($$;)
{
  my ($self, $path, $value) = @_;
  return undef if(ref $value eq 'HASH');
  my $values = $self->_fetcharray($path, 1);
  CORE::push @$values, scalar $value;
  return $value;
}

# Pop une valeur de la structure.
sub pop($;)
{
  my ($self, $path) = @_;
  my $values = $self->_fetcharray($path, 0);
  return CORE::pop @$values;
}

# Shift une valeur de la structure.
sub shift($;)
{
  my ($self, $path) = @_;
  my $values = $self->_fetcharray($path, 0);
  return CORE::shift @$values;
}

# Unshift une valeur dans la structure.
sub unshift($$;)
{
  my ($self, $path, $value) = @_;
  return undef if(ref $value eq 'HASH');
  my $values = $self->_fetcharray($path, 1);
  return CORE::unshift @$values, $value;
}

# Recherche la position sp�cifi� pour le dernier array.
# Retourne i si [i] est utilis�, 0 sinon.
# @param path
# @return position du dernier id dans le path.
sub _lastid($;)
{
  my ($self, $ref) = @_;
  return ($ref =~ m/.*\[(\d+)\]$/) ? $1 : 0;
}

# Effectue une recherche dans les donn�es et retourne
# le array sp�cifi� par le path.
# @param path
# @param create cr�e ou non lors de la recherche.
# @param r�f�rence sur le array des valeurs.
sub _fetcharray($$;)
{
  my ($self, $path, $create) = @_;
  my @sels = split(/\./, $path);
  my $data = $self->{data};
  my $index;

  for(my $i = 0; $i < scalar @sels; $i++){
    $index = $self->_lastid($sels[$i]);
    $sels[$i] =~ s/\[\d+\]//;

    return undef if(!defined $data->{$sels[$i]} && $create == 0);
    $data->{$sels[$i]} = [] if(!defined $data->{$sels[$i]});
    $data = $data->{$sels[$i]};
    
    if($i < scalar @sels -1){
      return undef if(!defined $$data[$index] && $create == 0);
      $$data[$index] = {} if(!defined $$data[$index]);
      $data = $$data[$index];
    }
  }

  return (ref $data eq 'ARRAY') ? $data : undef;
}


1;


__END__

