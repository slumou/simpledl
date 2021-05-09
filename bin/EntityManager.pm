# fhya : manage entities
# Hussein Suleman
# June 2019

package EntityManager;
require Exporter;

use strict;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT    = qw(loadEntities saveEntities addEntityMetadata addEntityItemRole createEntityFiles);

$| = 1;

use utf8;

use FindBin;
my $cwd = $FindBin::Bin;
#do "$cwd/config.pl";

my $dbDir = "$cwd/../../db";
my $userRenderDir = "$cwd/../../public_html/users";

my $entity_index = {};
my $entity_fastindex = {};
my $entity_id = 1;
my $entity_user_location = $userRenderDir;

sub authToName
{
   my ($an) = @_;
   if ($an =~ /([^, ]+( +[^, ]+)*) *, *(.*)/)
   { return "$3 $1"; }
   else
   { return $an; }
}

sub loadEntities
{
   if (-e "$dbDir/entity/entity_index.txt")
   {
      $entity_index = {};
      $entity_id = 1;
      open ( my $ifile, "<:utf8", "$dbDir/entity/entity_index.txt");
      while ( my $authname = <$ifile> )
      {
         chomp $authname;
         my $name = authToName ($authname);
         my $id = <$ifile>;
         chomp $id;
         if ($id > $entity_id)
         { $entity_id = $id + 1; }         
         my $metadata = <$ifile>;
         chomp $metadata;
         my $count = <$ifile>;
         chomp $count;
         if (! defined $entity_index->{$name})
         { 
            $entity_index->{$name} = [ $authname, $id, $metadata ]; 
            $entity_fastindex->{$name} = {};
         }
         for ( my $i=0; $i<$count; $i++ )
         {
            my $item = <$ifile>;
            my $title = <$ifile>;
            my $role = <$ifile>;
            my $date = <$ifile>;
            chomp $item;
            chomp $title;
            chomp $role;
            chomp $date;
            push (@{$entity_index->{$name}}, [ $item, $title, $role, $date ]);
            $entity_fastindex->{$name}->{join ('|', ($item, $role, $date))} = 1;
         }   
      }
      close ($ifile);
   }
}

sub saveEntities
{
   open ( my $ifile, ">:utf8", "$dbDir/entity/entity_index.txt");
   foreach my $name ( keys %{$entity_index} )
   {
      print $ifile $entity_index->{$name}->[0]."\n";
      print $ifile $entity_index->{$name}->[1]."\n";
      print $ifile $entity_index->{$name}->[2]."\n";
      my $count = ( $#{$entity_index->{$name}} - 2);
      print $ifile "$count\n";
      for ( my $i=0; $i<$count; $i++ )
      {
         print $ifile $entity_index->{$name}->[$i+3]->[0]."\n";
         print $ifile $entity_index->{$name}->[$i+3]->[1]."\n";
         print $ifile $entity_index->{$name}->[$i+3]->[2]."\n";
         print $ifile $entity_index->{$name}->[$i+3]->[3]."\n";
      }
   }
   close ($ifile);
}

sub addEntityMetadata
{
   my ($authname, $metadata) = @_;
   $authname =~ s/[\n\r]//go;
   $metadata =~ s/[\n\r]/CRLF/go;
   my $name = authToName ($authname);
   if (! defined $entity_index->{$name})
   { $entity_index->{$name} = [ $authname, $entity_id++, $metadata ]; }
   else
   { $entity_index->{$name}->[2] = $metadata; }
}

sub addEntityItemRole
{
   my ($authname, $item, $title, $role, $date) = @_;
   $authname =~ s/[\n\r]//go;
   $item =~ s/[\n\r]//go;
   $title =~ s/[\n\r]//go;
   $role =~ s/[\n\r]//go;
   my $name = authToName ($authname);
   if (! defined $entity_index->{$name})
   { 
      $entity_index->{$name} = [ $authname, $entity_id++, '' ]; 
      $entity_fastindex->{$name} = {};
   }
#   my $found == 0;
#   for ( my $i=3; $i<=$#{$entity_index->{$name}}; $i++ )
#   {
#      if (($entity_index->{$name}->[$i]->[0] eq $item) && 
#          ($entity_index->{$name}->[$i]->[2] eq $role) &&
#          ($entity_index->{$name}->[$i]->[3] eq $date))
#      {
#         $found = 1; 
#         last; 
#      }
#   }
#   if ($found == 0)
   if (! exists $entity_fastindex->{$name}->{join ('|', ($item, $role, $date))})   
   { 
      push (@{$entity_index->{$name}}, [ $item, $title, $role, $date ]); 
      $entity_fastindex->{$name}->{join ('|', ($item, $role, $date))} = 1;
   }
   return $entity_index->{$name}->[1];
}


sub createEntityFiles
{
   foreach my $name ( keys %{$entity_index} )
   {
      my $authname = $entity_index->{$name}->[0];
      my $id = $entity_index->{$name}->[1];
      my $metadata = $entity_index->{$name}->[2];
      $metadata =~ s/CRLF/\n/go;
      open ( my $ifile, ">:utf8", "$entity_user_location/internal$id.xml");
      print $ifile "<user>\n<type>Commissioned Contributor</type>\n";
      print $ifile "<name>$authname</name>\n";
      print $ifile "$metadata\n";
      my $count = ( $#{$entity_index->{$name}} - 2);
      for ( my $i=0; $i<$count; $i++ )
      {
         print $ifile "<contribution>\n";
         print $ifile " <item>".$entity_index->{$name}->[$i+3]->[0]."</item>\n";
         print $ifile " <title>".$entity_index->{$name}->[$i+3]->[1]."</title>\n";
         print $ifile " <role>".$entity_index->{$name}->[$i+3]->[2]."</role>\n";
         print $ifile " <date>".$entity_index->{$name}->[$i+3]->[3]."</date>\n";
         print $ifile "</contribution>\n";
      }
      print $ifile "</user>\n";
      close ($ifile);
   }   
}

# tests
#load_entities ();
#add_entity ('Mhlopekazi?', 'JAG/Brenthurst/1', 'Making');
#add_entity ('FHYA', 'JAG/Brenthurst/1', 'Curation');
#save_entities ();
#load_entities ();
#add_entity ('Mhlopekazi?', 'JAG/Brenthurst/2', 'Making');
#add_entity ('Grant', 'JAG/Brenthurst/2', 'Curation');
#add_entity ('FHYA', 'JAG/Brenthurst/2', 'Preservation');
#save_entities ();
#load_entities ();
#add_entity ('Mhlopekazi?', 'JAG/Brenthurst/1', 'Making');
#save_entities ();
#create_entity_files ();

