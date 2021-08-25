#!/usr/bin/perl

# SimpleDL: import metadata and static files
# Hussein Suleman
# 16 Jan 2021

$| = 1;

use File::Copy;
use Getopt::Long;
use Unicode::Normalize qw (NFC);
use utf8;

use FindBin;
use lib "$FindBin::Bin";
use EntityManager qw (:DEFAULT);
use CSV qw (:DEFAULT);

do "$FindBin::Bin/../../data/config/config.pl";

# check a list of source files against a list of destination files
sub needUpdate
{
   my ($source, $dest) = @_;
   
   foreach my $dfile (@$dest)
   {
      if (! -e $dfile)
      { return 1; }
      foreach my $sfile (@$source)
      {
         if (-M $sfile < -M $dfile)
         { return 1; }
      }
   }
   return 0;
}


# process all preset authority files and pre-populate authority lists
sub importAuthorities
{
   my ($source, $offset) = @_;
   
   opendir (my $dir, $source.$offset);
   my @dirs = readdir ($dir);
   closedir ($dir);
   @dirs = grep { !/^\./ } @dirs;
   
   foreach my $d (@dirs)
   {
      if (-d "$source$offset/$d")
      {
         importAuthorities ($source, "$offset/$d");
      }
      elsif ($d =~ /\.[cC][sS][vV]$/)
      {
         # print "Scanning CSV file: $d\n";
         my ($headings, $fields) = getCSV ("$source$offset/$d");
         
         # get positions of key elements
         my $typeOfEntity_position = getPos ($headings, "typeOfEntity");
         my $authorizedFormOfName_position = getPos ($headings, "authorizedFormOfName");

         # screen for authority files
         if ((defined $typeOfEntity_position) && (defined $authorizedFormOfName_position))
         {
            print "ENTITIES : Processing authorities file: $offset/$d\n";
                  
            for ( my $i=0; $i<=$#$fields; $i++ )
            {
               my $authname = $fields->[$i]->[$authorizedFormOfName_position];
               my $metadata = '';
               for ( my $j=0; $j<=$#$headings; $j++ )
               {
                  my $heading = $headings->[$j];
                  $value_bit = $fields->[$i]->[$j];
                  $metadata .= "<$heading>".XMLEscape ($value_bit)."</$heading>\n";
               }
               addEntityMetadata ($authname, $metadata);
            }
         }
      }
   }
}

# create simple 
sub createResolver
{
   my ($resolverDir, $destination, $offset, $filename, $uniqueId) = @_;
   
   open (my $file, ">:utf8", "$resolverDir/$uniqueId");
   print $file "<html><head>";
   print $file "<meta http-equiv=\"refresh\" content=\"0;URL='/metadata$offset/$filename/index.html\"/>";
   print $file "</head></html>\n";
   close ($file);    
}
               
# strip non-alphanumerics and lowercase strings
sub makeSlug
{
   my ($s) = @_;
#my $t=$s;   
   $s =~ s/^\s+|\s+$//g;   
   $s = lc (NFC($s));
   $s =~ s/'//g;
   $s =~ s/[^a-z0-9\x{00c0}-\x{00ff}\- ]//g;
   $s =~ s/ /\-/g;
#print "SLUG [$t] [$s]\n";   
   return $s;
}

# get a single table value
sub getVal
{
   my ($headings, $fields, $field) = @_;

   my $position = get_pos ($headings, $field);
   if (defined $position)
   { 
      my $v = $fields->[$position];
      $v =~ s/^\s*//;
      $v =~ s/\s*$//;
      return $v; 
   }

   undef;
}

# get position of a column
sub getPos
{
   my ($headings, $field) = @_;

   for ( my $i=0; $i<=$#$headings; $i++ )
   {
      if ($headings->[$i] eq $field)
      { return $i; }
   }
   
   undef;  
}

# process a directory of metadata spreadsheets
sub importDir
{
   my ($source, $destination, $offset, $level, $optForce, $resolverDir) = @_;
   
   mkdir ($destination);
   
   opendir (my $dir, $source.$offset);
   my @dirs = readdir ($dir);
   closedir ($dir);
   @dirs = grep { !/^\./ } @dirs;
   @dirs = sort { $a cmp $b } @dirs;
   
   # pull out files named "top level" to be processed first
   my @toplevels = grep { /top.?level/i } @dirs;
   my @nontoplevels = grep { !/top.?level/i } @dirs;
   @dirs = ( @toplevels, @nontoplevels );
   
   my @items = ();
   my $gotItems = 0;
   my $counter = 1;
   my %dirBySlug = ();
   my %levelBySlug = ();
   my %childrenByParent = ();
   my %levelsByParent = ();

   # process each entry in directory - first the CSV files
   foreach my $d (@dirs)
   {
      if ((! -d "$source$offset/$d") && ($d =~ /\.[cC][sS][vV]$/))
      {
         # print "Processing CSV file: $d\n";
         my ($headings, $fields) = getCSV ("$source$offset/$d");
         
         # get positions of key elements
         my $legacyId_position = getPos ($headings, "legacyId");
         my $parentId_position = getPos ($headings, "parentId");
         my $title_position = getPos ($headings, "title");
         my $digitalObjectPath_position = getPos ($headings, "digitalObjectPath");
         my $levelOfDescription_position = getPos ($headings, "levelOfDescription");
         my $authorizedFormOfName_position = getPos ($headings, "authorizedFormOfName");
         my %dirByLegacy = ();
         my %levelByLegacy = ();

         # check that these fields exist, or it is not an ATOM metadata file
         
         # determine CSV file type
         
         # check for authorities file
         if (defined $authorizedFormOfName_position)
         {
            print "METADATA : Skipping authorities file: $d\n";
            next;
         }
         
         # check for Atom-style metadata file
#         elsif (( defined $title_position ) &&
#                ( defined $legacyId_position ) &&
#                ( defined $parentId_position ) &&
#                ( defined $levelOfDescription_position ))
#         {
         print "METADATA : Processing CSV file: $d\n";
         
         # trim LoD fields
         if (defined $levelOfDescription_position)
         {
            for ( my $i=0; $i<=$#$fields; $i++ )
            {
               $fields->[$i]->[$levelOfDescription_position] =~ s/^\s+|\s+$//g;
               $fields->[$i]->[$levelOfDescription_position] = lc ($fields->[$i]->[$levelOfDescription_position]);
            }
         }
         
         for ( my $i=0; $i<=$#$fields; $i++ )
         {
            my $LoD = 'item';
            if (defined $levelOfDescription_position)
            {
               $LoD = $fields->[$i]->[$levelOfDescription_position];
            }   

            if (($LoD ne 'collection') && ($LoD ne 'view'))
            {
               #print "Detected $LoD metadata\n";
               my $filename = $counter;
               my $effectiveLevel = $level + 1;
               $counter++;
               my $createUniqueId = '';
               
               # use a fixed identifier if there is one
               if ((defined $fixedidentifier) && ($fixedidentifier ne ''))
               {
                  my $identifier_position = getPos ($headings, $fixedidentifier);
                  if ((defined $identifier_position) && ($fields->[$i]->[$identifier_position] ne ''))
                  {
                     $filename = $fields->[$i]->[$identifier_position];
                     $filename =~ s/^\s+|\s+$//g;
                     $filename =~ s/[^a-zA-Z0-9_\-\.]/_/go;
                     
                     # set flag to create simple resolver entry
                     $createUniqueId = $filename;
                  }
               }
                  
               # check for parent entry
               my $qubitParentSlug_position = getPos ($headings, "qubitParentSlug");
               my $parent = undef;
               if ((defined $qubitParentSlug_position) &&
                   ($fields->[$i]->[$qubitParentSlug_position] ne '') &&
                   (exists $dirBySlug{$fields->[$i]->[$qubitParentSlug_position]}))
               {
                  $parent = $dirBySlug{$fields->[$i]->[$qubitParentSlug_position]};
                  $effectiveLevel = $levelBySlug{$fields->[$i]->[$qubitParentSlug_position]} + 1;
               }
               elsif ((defined $parentId_position) &&
                      ($fields->[$i]->[$parentId_position] ne '') &&
                      (exists $dirByLegacy{$fields->[$i]->[$parentId_position]}))
               {
                  $parent = $dirByLegacy{$fields->[$i]->[$parentId_position]};
                  $effectiveLevel = $levelByLegacy{$fields->[$i]->[$parentId_position]} + 1;
               }
                  
               # save parent-child details for deferred generation of index 
               if (defined $parent)
               {
                  if (! exists $childrenByParent{$parent})
                  { 
                     $childrenByParent{$parent} = [];
                     $levelsByParent{$parent} = [ $effectiveLevel-1, 'collection' ];
                  }
                  push (@{$childrenByParent{$parent}}, $filename.'@type@'.$LoD);
                  $filename = $parent.'/'.$filename;
               }
               else
               {
                  $items[$#items+1] = $filename.'@type@'.$LoD;               
               }
               $childrenByParent{$filename} = [];
               $levelsByParent{$filename} = [ $effectiveLevel, $LoD ];
               
               # create simple resolver entry
               if ($createUniqueId ne '')
               {
#                  print "*** $resolverDir, $destination, $offset, $filename $createUniqueId";
                  createResolver ($resolverDir, $destination, $offset, $filename, $createUniqueId);
               }
                  
               # set locations for future child elements
               if ((defined $title_position) &&
                   ($fields->[$i]->[$title_position] ne ''))
               {
                  my $slug = makeSlug ($fields->[$i]->[$title_position]);
                  $dirBySlug{$slug} = $filename;
                  $levelBySlug{$slug} = $effectiveLevel;
               }
               if ((defined $legacyId_position) &&
                   ($fields->[$i]->[$legacyId_position] ne ''))
               {
                  $dirByLegacy{$fields->[$i]->[$legacyId_position]} = $filename;
                  $levelByLegacy{$fields->[$i]->[$legacyId_position]} = $effectiveLevel;
               }

               # gather all views (if there are views of this item)
               if (defined $digitalObjectPath_position)
               {
                  my @views = ();
                  if ($fields->[$i]->[$digitalObjectPath_position] !~ /^\s*$/)
                  {  
                     my $title = '';
                     if (defined $title_position)
                     {
                        $title = $fields->[$i]->[$title_position];
                     }
                     @views = ($title, $fields->[$i]->[$digitalObjectPath_position]); 
                  }
                  for ( my $j=0; $j<=$#$fields; $j++ )
                  { 
                     # match parent (item) and child (view) rows
                     if ((defined $legacyId_position) && (defined $parentId_position) && (defined $levelOfDescription_position) &&
                         ($fields->[$i]->[$legacyId_position] eq $fields->[$j]->[$parentId_position]) &&
                         ($fields->[$j]->[$levelOfDescription_position] eq 'view'))
                     {
                        my $title = '';
                        if (defined $title_position)
                        {
                           $title = $fields->[$j]->[$title_position];
                        }
                        @views = (@views, $title, $fields->[$j]->[$digitalObjectPath_position]); 
                     }
                  }
                  # strip prefixes from view locations
                  for ( my $k=0; $k<=$#views; $k+=2 )
                  {
                     $views[$k+1] =~ s/\/uploads\/fhya\/(.*)/$1/;
                     $views[$k+1] =~ s/\/uploads\/(.*)/$1/;
                  }
                  $fields->[$i]->[$digitalObjectPath_position] = join ($separatorClean, @views);
               }

               # write XML
               if (($filename ne '') && ((needUpdate (["$source$offset/$d"], ["$destination$offset/$filename/metadata.xml"])) || ($optForce)))
               {
                  print "METADATA : Generating $LoD $destination$offset/$filename/metadata.xml\n";
                  if (! -e "$destination$offset/$filename")
                  {
                     # print "Creating directory $destination$offset/$filename\n";
                     mkdir ("$destination$offset/$filename");
                  }
                  createXML ("$destination$offset/$filename/metadata.xml", substr ("$offset/$filename", 1), "item", $headings, $fields->[$i]);

                     # output blank index file if it is not there
                     #if (! -e "$destination$offset/$filename/index.xml")
                     #{
                     #   print "Generating $destination$offset/$filename/index.xml\n";
                     #   create_XML ("$destination$offset/$filename/index.xml", "", "collection", [ "item", "level", "type" ], [ join ('|', ()), $effectiveLevel, $LoD ]);
                     #}
               }
            }
            elsif ($LoD eq 'collection')
            {
               #print "Detected collection metadata\n";
                  
               if (! defined $legacyId_position)
               { next; }
               my $filename = $fields->[$i]->[$legacyId_position];

               # update views to point to logo
               if (defined $digitalObjectPath_position)
               {
                  if ($fields->[$i]->[$digitalObjectPath_position] =~ /uploads\/fhya\/(.*)/)
                  {
                     $fields->[$i]->[$digitalObjectPath_position] = join ($separatorClean, ('Logo', $1));
                  }
                  elsif ($fields->[$i]->[$digitalObjectPath_position] =~ /uploads\/(.*)/)
                  {
                     $fields->[$i]->[$digitalObjectPath_position] = join ($separatorClean, ('Logo', $1));
                  }
                  else
                  {
                     $fields->[$i]->[$digitalObjectPath_position] = join ($separatorClean, ('Logo', $fields->[$i]->[$digitalObjectPath_position]));
                  }
               }   
         
               # write XML
               if (($filename ne '') && ((needUpdate (["$source$offset/$d"], ["$destination$offset/$filename/metadata.xml"])) || ($optForce)))
               {
                  print "METADATA : Generating $LoD $destination$offset/$filename/metadata.xml\n";
                  if (! -e "$destination$offset/$filename")
                  {
                     print "METADATA : Creating directory $destination$offset/$filename\n";
                     #my $x = 
                     mkdir ("$destination$offset/$filename");
                     #if (! $x) { print "X $x !! $! \n"; }
                  }
                  $items[$#items+1] = $filename.'@type@collection';
                  createXML ("$destination$offset/$filename/metadata.xml", "", "item", $headings, $fields->[$i]);

                  # output blank index file if it is not there
                  #if (! -e "$destination$offset/$filename/index.xml")
                  #{
                  #   print "Generating $destination$offset/$filename/index.xml\n";
                  #   createXML ("$destination$offset/$filename/index.xml", "", "collection", [ "item", "level", "type" ], [ '', $level, $LoD ]);
                  #}
               }
            }  
         }
      }
   }
   # process each entry in directory - then the directories
   foreach my $d (@dirs)
   {
      # if it is a directory
      if (-d "$source$offset/$d")
      {
         print "METADATA : Processing directory: $offset/$d\n";
         if (! -e "$destination$offset/$d")
         {
            print "METADATA : Creating directory $destination$offset/$d\n";
            mkdir ("$destination$offset/$d");
         }   
         importDir ($source, $destination, "$offset/$d", $level+1, $optForce, $resolverDir);
      }
   }
   
   # generate auto listing if no top-level or series or collection
   if ($#items == -1)
   {
      # generate index of items from destination directory
      opendir (my $dir, $destination.$offset);
      @items = readdir ($dir);
      closedir ($dir);
      @items = grep { !/^\./ } @items;
      @items = sort { $a cmp $b } @items;
      @items = grep { -d "$destination$offset/$_" } @items;
   }
   
   # prefix each directory, to create list of source spreadsheets
   @dirs = map { "$source$offset/$_" } @dirs; 
#print "*** [".join ('] [', @dirs)."]\n";   
   # output index file
   if ((needUpdate (\@dirs, ["$destination$offset/index.xml"])) || ($optForce))
   {
      print "METADATA : Generating $destination$offset/index.xml\n";
      createXML ("$destination$offset/index.xml", "", "collection", [ "item", "level", "type" ], [ join ($separatorClean, @items), $level, $LoD ]);
   }
   
   # output blank metadata file if it is not there
   if (! -e "$destination$offset/metadata.xml")
   {
      print "METADATA : Generating $destination$offset/metadata.xml\n";
      createXML ("$destination$offset/metadata.xml", "", "item", [], []);
   }
   
   # cycle through and generate deferred index files
   foreach my $parent (keys %childrenByParent)
   {
      if ((needUpdate (\@d, ["$destination$offset/$parent/index.xml"])) || ($optForce))
      {
         # output index file
         print "METADATA : Generating deferred $destination$offset/$parent/index.xml\n";
         createXML ("$destination$offset/$parent/index.xml", "", "collection", [ "item", "level", "type" ], [ join ($separatorClean, @{$childrenByParent{$parent}}), $levelsByParent{$parent}->[0], $levelsByParent{$parent}->[1] ]);
      }
   }
}

sub XMLEscape
{
   my ($value) = @_;
   
   $value =~ s/\&/\&amp;/go;
   $value =~ s/\</\&lt;/go;
   $value =~ s/\>/\&gt;/go;
   $value =~ s/\'/\&apos;/go;
   $value =~ s/\"/\&quot;/go;
   
   return $value;
}

sub URLEscape
{
   my ($value) = @_;
   
   $value =~ s/ /%20/go;
   
   return $value;
}

sub createXML
{
   my ($filename, $itemlocation, $container, $headings, $values) = @_;

   open (my $file, ">:utf8", "$filename");
   print $file "<$container>\n";
   
   my ($eventActors, $eventTypes, $eventDates, $eventDescriptions, $digitalObjectPath, $creators, $cdate) = ('', '', '', '', '', '', '');
   my $title = '';
    
   for ( my $i=0; $i<=$#$headings; $i++ )
   {
      my $heading = $headings->[$i];

      # trim start and end spaces in tag name
      $heading =~ s/\s+$//;
      $heading =~ s/^\s+//;      

      # special processing for structured event Atom fields and for links to objects
      if ($heading eq 'eventActors')
      { $eventActors = $values->[$i]; }
      elsif ($heading eq 'eventTypes')
      { $eventTypes = $values->[$i]; }
      elsif ($heading eq 'eventDates')
      { $eventDates = $values->[$i]; }
      elsif ($heading eq 'eventDescriptions')
      { $eventDescriptions = $values->[$i]; }
      elsif ($heading eq 'digitalObjectPath')
      { $digitalObjectPath = $values->[$i]; }
      elsif ($heading eq 'creator')
      { $creators = $values->[$i]; }

      # otherwise simply output fields
      else
      {
         my $value = $values->[$i];
         if ($value ne '')
         {
            foreach my $value_bit (split ($separator, $value))
            {
               my $attributes = '';
               my @valueattrbit = split ('@', $value_bit);
               $value_bit = $valueattrbit[0];
               for ( my $j=1; $j<=$#valueattrbit; $j+=2 )
               {
                  $attributes .= " $valueattrbit[$j]=\"$valueattrbit[$j+1]\"";
               }
               my $sep2 = $separator2;
               $sep2 =~ s/\\//go;
               if (index ($value_bit, $sep2) > -1)
               {
#print "FOUND $heading $value_bit $separator $separator2 \n";
                  my $subfieldIndicator = 'a';
                  $value_bit =~ s/\s+$//;
                  $value_bit =~ s/^\s+//;               
                  if ($heading ne '')
                  {
                     print $file "   <$heading$attributes>\n";
                  }
                  foreach my $value_bit2 (split ($separator2, $value_bit))
                  {
                     if ($heading eq 'relatedUnitsOfDescription')
                     {
                        print $file "      <$subfieldIndicator>".XMLEscape (URLEscape ($value_bit2))."</$subfieldIndicator>\n";
                     }
                     elsif ($heading ne '')
                     {
                        print $file "   <$subfieldIndicator>".XMLEscape ($value_bit2)."</$subfieldIndicator>\n";
                        if ($heading eq 'title')
                        { $title = XMLEscape ($value_bit2); }
                        if ($heading eq 'date')
                        { $cdate = XMLEscape ($value_bit2); }
                     }
                     $subfieldIndicator++;
                  } 
                  if ($heading ne '')
                  {
                     print $file "   </$heading>\n";
                  }
               } 
               else
               {
                  $value_bit =~ s/\s+$//;
                  $value_bit =~ s/^\s+//;               
                  if ($heading eq 'relatedUnitsOfDescription')
                  {
                     print $file "   <$heading$attributes>".XMLEscape ($value_bit)."</$heading>\n";
#                     print $file "   <$heading$attributes>".XMLEscape (URLEscape ($value_bit))."</$heading>\n";
                  }
                  elsif ($heading ne '')
                  {
                     print $file "   <$heading$attributes>".XMLEscape ($value_bit)."</$heading>\n";
                     if ($heading eq 'title')
                     { $title = XMLEscape ($value_bit); }
                     if ($heading eq 'date')
                     { $cdate = XMLEscape ($value_bit); }
                  }
               }  
            }
         }   
      }
   }

   my @eventActors_list = split ('\|', XMLEscape ($eventActors));
   my @eventTypes_list = split ('\|', XMLEscape ($eventTypes));
   my @eventDates_list = split ('\|', XMLEscape ($eventDates));
   my @eventDescriptions_list = split ('\|', XMLEscape ($eventDescriptions));
   if (($#eventActors_list == $#eventTypes_list) && 
       ($#eventTypes_list == $#eventDates_list))
#        && 
#       ($#eventDates_list == $#eventDescriptions_list))
   {
      for ( my $i = 0; $i <= $#eventActors_list; $i++ )
      {
         my $actorId = '';
         if ($itemlocation ne '')
         { 
            $actorId = addEntityItemRole ($eventActors_list[$i], $itemlocation, $title, $eventTypes_list[$i], $eventDates_list[$i]);
            $actorId = " id=\"internal$actorId\""; 
         }
         print $file "   <event>\n".
                     "      <eventActor$actorId>$eventActors_list[$i]</eventActor>\n".
                     "      <eventType>$eventTypes_list[$i]</eventType>\n".
                     "      <eventDate>$eventDates_list[$i]</eventDate>\n".
                     "      <eventDescription>$eventDescriptions_list[$i]</eventDescription>\n".
                     "   </event>\n";
      }
   }
   
   # process creators as entities and add IDs to each
   my @creators_list = split ('\|', XMLEscape ($creators));
   for ( my $i = 0; $i <= $#creators_list; $i++ )
   {
      my $actorId = '';
      if ($itemlocation ne '')
      { 
         $actorId = addEntityItemRole ($creators_list[$i], $itemlocation, $title, 'author', $cdate);
         $actorId = " id=\"internal$actorId\""; 
      }
      print $file "   <creator$actorId>$creators_list[$i]</creator>\n";
   }

#print "***".$digitalObjectPath."\n";
   my @digitalObjectPath_list = split ($separator, XMLEscape ($digitalObjectPath));
   for ( my $i = 0; $i <= $#digitalObjectPath_list; $i+=2 )
   {
      $digitalObjectPath_list[$i] =~ s/\s+$//;
      $digitalObjectPath_list[$i] =~ s/^\s+//;
      $digitalObjectPath_list[$i+1] =~ s/\s+$//;
      $digitalObjectPath_list[$i+1] =~ s/^\s+//;
      print $file "   <view>\n".
                  "      <title>$digitalObjectPath_list[$i]</title>\n".
                  "      <file>".URLEscape ($digitalObjectPath_list[$i+1])."</file>\n".
                  "   </view>\n";
   }
         
   print $file "</$container>\n";
   close ($file);
}

# merge user entries into full records
sub importUsers
{
   my ($source, $destination) = @_;
   
   mkdir ($destination);

   opendir (my $dir, $source);
   my @users = readdir ($dir);
   closedir ($dir);
   @users = grep { /[0-9]+\.name\.xml/ } @users;
   
   # process each entry in directory
   foreach my $u (@users)
   {
      if ($u =~ /([0-9]+)\.name\.xml/)
      {
         my $userID = $1;
         
         # user entry globs
         my $maxuserlen = 6;
         my $maxuserglob = join ('', map { '?' } 1..$maxuserlen);

         # merge user bits into a single file
         print "USERS    : Importing user $userID\n";
         system ("echo \'<user><type>$vocab->{'PublicContributor'}</type>\' > $destination/$userID.xml; ".
           "cat $userDir/$userID.name.xml >> $destination/$userID.xml 2>/dev/null; ".
           "cat $userDir/$userID.profile.xml >> $destination/$userID.xml 2>/dev/null; ".
           "cat $userDir/$userID.$maxuserglob.xml >> $destination/$userID.xml 2>/dev/null; ".
           "echo \'</user>\' >> $destination/$userID.xml; ".
           "chmod a+w $destination/$userID.xml");
      }
   }
}

sub importComments
{
   my ($metadata, $source, $destination, $offset) = @_;
   
   opendir (my $dir, $metadata.$offset);
   my @dirs = readdir ($dir);
   closedir ($dir);
   @dirs = grep { !/^\./ } @dirs;

   # get comment file template
   my $maxcommentlen = 6;
   my $maxcommentglob = join ('', map { '?' } 1..$maxcommentlen);
   
   # process each entry in directory
   foreach my $d (@dirs)
   {
      # if it is a directory
      if (-d "$metadata$offset/$d")
      {
         print "COMMENTS : Processing item $offset/$d\n";
         if (! -e "$destination$offset/$d")
         {
            print "COMMENTS : Creating directory $destination$offset/$d\n";
            mkdir ("$destination$offset/$d");
         }
         
         # merge comments into a single file
         system ("echo \'<comments>\' > \'$destination$offset/$d/metadata.xml\'; ".
                 "cat \'$source$offset/$d/\'$maxcommentglob.xml >> \'$destination$offset/$d/metadata.xml\' 2>/dev/null; ".
                 "echo \'</comments>\' >> \'$destination$offset/$d/metadata.xml\'; ".
                 "chmod a+w \'$destination$offset/$d/metadata.xml\'");
         
         importComments ($metadata, $source, $destination, "$offset/$d");
      }
   }
}

sub importUploads
{
   my ($source, $destination, $offset, $level) = @_;

   # get list of uploads
   opendir (my $dir, $source.$offset);
   my @uploads = readdir ($dir);
   closedir ($dir);
   @uploads = grep { !/^\./ } @uploads;
   @uploads = sort { $b <=> $a } @uploads;
   
   # determine type at this level and if there is a metadata.xml
   my $type = 'series';
   my $gotMetadata = 0;
   foreach my $u (@uploads)
   {
      if ($u eq 'metadata.xml')
      {
         $gotMetadata = 1;
         break;
      }
   }
   if (($#uploads == 0) && ($gotMetadata == 1))
   { $type = 'item'; }

   # process each entry in uploads directory
   open (my $ifile, ">:utf8", "$destination$offset/index.xml");
   print $ifile "<collection>\n<level>$level</level>\n<type>$type</type>\n";
   foreach my $u (@uploads)
   {
      # recurse over directories
      if (-d "$source$offset/$u")
      {
         # create dest directory
         if (! -e "$destination$offset/$u")
         { mkdir ("$destination$offset/$u"); }
         # import at inner level
         my $innerType = importUploads ($source, $destination, $offset.'/'.$u, $level+1);
         print $ifile "<item type=\"$innerType\">$u</item>\n";
      }
      else
      {
         # create metadata file
         if (needUpdate (["$source$offset/$u"], ["$destination$offset/$u"]))
         {
            print "UPLOADS  : Processing uploaded item: $offset\n";
            system ("cp \'$source$offset/$u\' \'$destination$offset/$u\'");
         }   
      }   
   }
   print $ifile "</collection>\n";
   close ($ifile);
   
   # if no metadata file, create one
   if (($type eq 'series') && ($gotMetadata == 0) && (! -e "$destination$offset/metadata.xml"))
   {
      my $title = $destination.$offset;
      if ($title =~ /\/([^\/]+)$/)
      { $title = $1; }
   
      open (my $ifile, ">:utf8", "$destination$offset/metadata.xml");
      print $ifile "<item>\n".
                   "<title>$title</title>\n".
                   "</item>\n";
      close ($ifile);
   }
   
   return $type;
}

# make a clean directory and archive old directory
sub archiveClean
{
   my ($dir) = @_;

   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime ();
   my $stamp = sprintf ("%04d-%02d-%02d.%d", $year+1900, $mon+1, $mday, $$);

   print ("CLEAN    : Moving $dir to $dir.$stamp\n");
   move ($dir, "$dir.$stamp");
   print ("CLEAN    : Recreating directory $dir\n");
   mkdir ($dir);   
}


# main program body
sub main
{
   # save the old metadata directory
   #my $timenow = time();
   #system ("mv $cwd/../public_html/metadata $cwd/../public_html/metadata.".$timenow);
   #mkdir ("$cwd/../public_html/metadata");

   my ($optForce, $optClean, $optHelp, $optUsers, $optDir, $optComments, $optUploads, $optAll) = (0, 0, 0, 0, 0, 0, 0, 0);
   my $optionsOK = GetOptions ('help|?' => \$optHelp, 
                               'comments' => \$optComments,
                               'dir' => \$optDir,
                               'uploads' => \$optUploads,
                               'users' => \$optUsers,
                               'all' => \$optAll,
                               'force' => \$optForce,
                               'clean' => \$optClean
                               );
   
   # if error or help asked for
   if (($optionsOK == 0) || ($optHelp == 1))
   {
      print <<EOC;
import.pl [options]

Options:
 --help       this information
 --comments   import comments
 --dir        import all metadata (default if no options specified)
 --uploads    import uploaded files/metadata
 --users      import users
 --all        full data import
 --force      force import of data
 --clean      clean directory first (metadata+entities/users/comments)
EOC
      return;
   }
   
   print "SimpleDL: Import Source Data\n\n";

   # if no options, default to processing only metadata
   if (($optHelp == 0) && ($optComments == 0) && ($optDir == 0) && ($optUploads == 0) && ($optUsers == 0) && ($optAll == 0))
   {
      $optDir = 1;
   }
   # if full import requested, set all options to true
   if ($optAll == 1)
   {
      ($optComments, $optDir, $optUploads, $optUsers) = (1, 1, 1, 1); 
   }

   # check each individual option   
   if ($optUsers == 1) 
   { 
      print "Importing users\n";
      if ($optClean == 1)
      {
         archiveClean ($userRenderDir);
      }
      importUsers ($userDir, $userRenderDir);
      print "\n";
   }
   if ($optDir == 1) 
   {
      print "Importing metadata and entities\n";
      if ($optClean == 1)
      {
         archiveClean ($dbDir.'/entity');
         archiveClean ($metadataDir);
      }
      if (! -e $resolverDir)
      {
         mkdir ($resolverDir);
      }
      loadEntities ();
      importAuthorities ($spreadsheetDir);
      importDir ($spreadsheetDir, $metadataDir, '', 1, $optForce, $resolverDir);
      saveEntities ();
      createEntityFiles ();
      print "\n";
   }
   if ($optComments == 1)
   {
      print "Importing comments\n";
      if ($optClean == 1)
      {
         archiveClean ($commentRenderDir);
      }
      importComments ($metadataDir, $commentDir, $commentRenderDir, '');
      print "\n";
   }
   if ($optUploads == 1)
   {
      print "Importing uploads\n";
      importUploads ($uploadDir, "$metadataDir/$uploadMetadataLocation", '', 2);
      print "\n";
   }
   
   print "SimpleDL: Import Complete\n\n";
}

main ();


