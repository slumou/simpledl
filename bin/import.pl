#!/usr/bin/perl

# SimpleDL: import metadata and static files
# Hussein Suleman
# 16 Jan 2021

$| = 1;

use Unicode::Normalize qw (NFD);
use utf8;

use FindBin;
use lib "$FindBin::Bin";
use EntityManager qw (:DEFAULT);
use CSV qw (:DEFAULT);

do "$FindBin::Bin/../../data/config/config.pl";


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
            print "Processing authorities file: $offset/$d\n";
                  
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
               
# strip non-alphanumerics and lowercase strings
sub makeSlug
{
   my ($s) = @_;
   
   $s =~ s/^\s+|\s+$//g;   
   $s = lc (NFD($s));
   $s =~ s/'//g;
   $s =~ s/[^a-z0-9\- ]//g;
   $s =~ s/ /\-/g;
   
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
   my ($source, $destination, $offset, $level) = @_;
   
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

   # process each entry in directory
   foreach my $d (@dirs)
   {
      # if it is a directory
      if (-d "$source$offset/$d")
      {
         print "Processing directory: $offset/$d\n";
         if (! -e "$destination$offset/$d")
         {
            print "Creating directory $destination$offset/$d\n";
            mkdir ("$destination$offset/$d");
         }   
         importDir ($source, $destination, "$offset/$d", $level+1);
      }
      elsif ($d =~ /\.[cC][sS][vV]$/)
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
            print "Skipping authorities file: $d\n";
            next;
         }
         
         # check for Atom-style metadata file
#         elsif (( defined $title_position ) &&
#                ( defined $legacyId_position ) &&
#                ( defined $parentId_position ) &&
#                ( defined $levelOfDescription_position ))
#         {
         print "Processing CSV file: $d\n";
         
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

            if ($LoD ne 'collection')
            {
               print "Detected $LoD metadata\n";
               my $filename = $counter;
               my $effectiveLevel = $level + 1;
               $counter++;
                  
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
                  $fields->[$i]->[$digitalObjectPath_position] = join ('|', @views);
               }   

               # write XML
               if ($filename ne '')
               {
                  print "Generating $destination$offset/$filename/metadata.xml\n";
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
               print "Detected collection metadata\n";
                  
               if (! defined $legacyId_position)
               { next; }
               my $filename = $fields->[$i]->[$legacyId_position];

               # update views to point to logo
               if (defined $digitalObjectPath_position)
               {
                  if ($fields->[$i]->[$digitalObjectPath_position] =~ /uploads\/fhya\/(.*)/)
                  {
                     $fields->[$i]->[$digitalObjectPath_position] = join ('|', ('Logo', $1));
                  }
                  elsif ($fields->[$i]->[$digitalObjectPath_position] =~ /uploads\/(.*)/)
                  {
                     $fields->[$i]->[$digitalObjectPath_position] = join ('|', ('Logo', $1));
                  }
               }   
         
               # write XML
               if ($filename ne '')
               {
                  print "Generating $destination$offset/$filename/metadata.xml\n";
                  if (! -e "$destination$offset/$filename")
                  {
                     print "Creating directory $destination$offset/$filename\n";
                     mkdir ("$destination$offset/$filename");
                  }
                  $items[$#items+1] = $filename.'@type@collection';
                  createXML ("$destination$offset/$filename/metadata.xml", "", "item", $headings, $fields->[$i]);
               }
            }  
         }
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
   
   # output index file
   print "Generating $destination$offset/index.xml\n";
   createXML ("$destination$offset/index.xml", "", "collection", [ "item", "level", "type" ], [ join ('|', @items), $level, $LoD ]);
   
   # output blank metadata file if it is not there
   if (! -e "$destination$offset/metadata.xml")
   {
      print "Generating $destination$offset/metadata.xml\n";
      createXML ("$destination$offset/metadata.xml", "", "item", [], []);
   }
   
   # cycle through and generate deferred index files
   foreach my $parent (keys %childrenByParent)
   {
      # output index file
      print "Generating $destination$offset/$parent/index.xml\n";
      createXML ("$destination$offset/$parent/index.xml", "", "collection", [ "item", "level", "type" ], [ join ('|', @{$childrenByParent{$parent}}), $levelsByParent{$parent}->[0], $levelsByParent{$parent}->[1] ]);
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

   open (my $file, ">$filename");
   print $file "<$container>\n";
   
   my ($eventActors, $eventTypes, $eventDates, $eventDescriptions, $digitalObjectPath) = ('', '', '', '', '');
   my $title = '';
    
   for ( my $i=0; $i<=$#$headings; $i++ )
   {
      my $heading = $headings->[$i];

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

      # otherwise simply output fields
      else
      {
         my $value = $values->[$i];
         if ($value ne '')
         {
            foreach my $value_bit (split ('\|', $value))
            {
               my $attributes = '';
               my @valueattrbit = split ('@', $value_bit);
               $value_bit = $valueattrbit[0];
               for ( my $j=1; $j<=$#valueattrbit; $j+=2 )
               {
                  $attributes .= " $valueattrbit[$j]=\"$valueattrbit[$j+1]\"";
               }
               $value_bit =~ s/\s+$//;
               $value_bit =~ s/^\s+//;
               if ($heading eq 'relatedUnitsOfDescription')
               {
                  print $file "   <$heading$attributes>".XMLEscape (URLEscape ($value_bit))."</$heading>\n";
               }
               elsif ($heading ne '')
               {
                  print $file "   <$heading$attributes>".XMLEscape ($value_bit)."</$heading>\n";
                  if ($heading eq 'title')
                  { $title = XMLEscape ($value_bit); }
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
            $actorId = addEntityItemRole ($eventActors_list[$i], $itemlocation, $title, $eventTypes_list[$i]);
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

   my @digitalObjectPath_list = split ('\|', XMLEscape ($digitalObjectPath));
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
         print "Processing item $offset/$d\n";
         if (! -e "$destination$offset/$d")
         {
            print "Creating directory $destination$offset/$d\n";
            mkdir ("$destination$offset/$d");
         }
         
         # merge comments into a single file
         system ("echo \'<comments>\' > \'$destination$offset/$d/metadata.xml\'; ".
                 "cat \'$source$offset/$d.\'$maxcommentglob.xml >> \'$destination$offset/$d/metadata.xml\' 2>/dev/null; ".
                 "echo \'</comments>\' >> \'$destination$offset/$d/metadata.xml\'; ".
                 "chmod a+w \'$destination$offset/$d/metadata.xml\'");         
         
         importComments ($metadata, $source, $destination, "$offset/$d");
      }
   }
}

sub importUploads
{
   my ($source, $destination) = @_;

   # get list of uploads
   opendir (my $dir, $source);
   my @uploads = readdir ($dir);
   closedir ($dir);
   @uploads = grep { /[0-9]/ } @uploads;
   @uploads = sort { $b cmp $a } @uploads;
   
   # process each entry in uploads directory
   open (my $ifile, ">$destination/index.xml");
   print $ifile "<collection>\n<level>2</level>\n<type>series</type>\n";
   foreach my $u (@uploads)
   {
      print "Processing uploaded item: $u\n";

      if (-e "$source/$u/metadata.xml")
      {
         # create item directory
         if (! -e "$destination/$u")
         {
            mkdir ("$destination/$u");
         }
         
         # create metadata file
         system ("cp \'$source/$u/metadata.xml\' \'$destination/$u/metadata.xml\'");
         
         # create index file
         open (my $file, ">$destination/$u/index.xml");
         print $file "<collection>\n<level>3</level>\n<type>item</type>\n</collection>\n";
         close ($file);
         
         # add entry to main index
         print $ifile "<item type=\"item\">$u</item>\n";
      }
   }
   print $ifile "</collection>\n";
}

sub main
{
   # save the old metadata directory
   #my $timenow = time();
   #system ("mv $cwd/../public_html/metadata $cwd/../public_html/metadata.".$timenow);
   #mkdir ("$cwd/../public_html/metadata");

   # process entities and metadata
   loadEntities ();
   importAuthorities ($spreadsheetDir);
   importDir ($spreadsheetDir, $metadataDir, '', 1);
   saveEntities ();
   createEntityFiles ();
   
   # process users
   importUsers ($userDir, $userRenderDir);
   
   # process comments
   importComments ($metadataDir, $commentDir, $commentRenderDir, '');
   
   # process uploads
   importUploads ($uploadDir, "$metadataDir/$uploadMetadataLocation");
}

main ();