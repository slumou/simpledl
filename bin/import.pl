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
         my $uniqueIdentifier_position = getPos ($headings, $fixedidentifier);
         my $id = undef;

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
               if (defined $uniqueIdentifier_position)
               {
                  my $testId = $fields->[$i]->[$uniqueIdentifier_position];
                  if ($testId !~ /^\s*$/)
                  {
                     $id = $testId;
                  }
               }
               addEntityMetadata ($authname, $id, $metadata);
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
   $s =~ s/^\s+//;
   $s =~ s/\s+$//;
   $s = lc (NFC($s));
   $s =~ s/'//g;
   $s =~ s/[^a-z0-9\x{00c0}-\x{00ff}\- ]//g;
   $s =~ s/ /\-/g;
#print "SLUG [$t] [$s]\n";   
   return $s;
}

# trim leading and trailing whitespace
sub trimws
{
   my ($s) = @_;
   $s =~ s/^\s+//;
   $s =~ s/\s+$//;
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
      $v =~ s/^\s+//;
      $v =~ s/\s+$//;
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
   my ($source, $destination, $optForce, $resolverDir) = @_;

   # to track index entries as metadata is processed
   my $childrenByParent = {};

   importMetadata ($source, $destination, '', $optForce, $resolverDir, $childrenByParent);
   importIndex ($destination, '', 1, $optForce, $resolverDir, $childrenByParent);
}

# propagate index files through system
sub importIndex
{
   my ($destination, $offset, $level, $optForce, $resolverDir, $childrenByParent) = @_;
   
   # get destination contents
   opendir (my $dir, $destination.$offset);
   my @dirs = readdir ($dir);
   closedir ($dir);
   @dirs = grep { !/^\./ } @dirs;
   @dirs = sort { $a cmp $b } @dirs;

   # process each entry in directory
   foreach my $d (@dirs)
   {
      # recurse into directories
      if (-d "$destination$offset/$d")
      {
         importIndex ($destination, "$offset/$d", $level+1, $optForce, $resolverDir, $childrenByParent);

         # check that directory is in children listing or add it
         my $found = 0;
         my $searchstring = $d.'@';
         foreach my $entry (@{$childrenByParent->{$offset}})
         {
            if (index ($entry, $searchstring) != -1)
            { $found = 1; }
         }
         if ($found == 0)
         {
            push (@{$childrenByParent->{$offset}}, "$d\@type\@series");
         }
      }
   }      
         
   # check that metadata file exists
   if (! -e "$destination$offset/metadata.xml")
   {
      if (createXML ("$destination$offset/metadata.xml", "", "item", [], []))
      {
         print "METADATA : Generating $destination$offset/metadata.xml\n";
      }      
   }
      
   # create index.xml
   if (! defined $childrenByParent->{$offset})
   {
      $childrenByParent->{$offset} = [];
   }
   if (createXML ("$destination$offset/index.xml", "", "collection", [ "item", "level" ], [ join ($separatorClean, @{$childrenByParent->{$offset}}), $level ]))
   {
      print "METADATA : Generating $destination$offset/index.xml\n";
   }
}

# propagate metadata through system from spreadsheets
sub importMetadata
{
   my ($source, $destination, $offset, $optForce, $resolverDir, $childrenByParent) = @_;
   
   mkdir ($destination) if (! -e "$destination");

   # get listing of source files   
   opendir (my $dir, $source.$offset);
   my @dirs = readdir ($dir);
   closedir ($dir);
   @dirs = grep { !/^\./ } @dirs;
   @dirs = sort { $a cmp $b } @dirs;
   
   # pull out files named "top level" to be processed first
   my @toplevels = grep { /top.?level/i } @dirs;
   my @nontoplevels = grep { !/top.?level/i } @dirs;
   @dirs = ( @toplevels, @nontoplevels );
   
   my $counter = 1;    # for automatic filenames 
   my %dirBySlug = (); # slugs tracked across files but not directories

   # process each entry in directory - first the CSV files
   foreach my $d (@dirs)
   {
      if ((! -d "$source$offset/$d") && ($d =~ /\.[cC][sS][vV]$/))
      {
         # read CSV and add in extra fields to help content developers
         my ($headings, $fields) = getCSV ("$source$offset/$d");
         $headings->[$#$headings+1] = 'spreadsheet';
         $headings->[$#$headings+1] = 'slug';
         
         # get positions of key elements
         my $legacyId_position = getPos ($headings, "legacyId");
         my $parentId_position = getPos ($headings, "parentId");
         my $title_position = getPos ($headings, "title");
         my $digitalObjectPath_position = getPos ($headings, "digitalObjectPath");
         my $levelOfDescription_position = getPos ($headings, "levelOfDescription");
         my $authorizedFormOfName_position = getPos ($headings, "authorizedFormOfName");
         my %dirByLegacy = ();

         # check for authorities file or process current file
         if (defined $authorizedFormOfName_position)
         {
            print "METADATA : Skipping authorities file: $d\n";
            next;
         }         
         print "METADATA : Processing CSV file: $d\n";
         
         # trim LoD fields
         if (defined $levelOfDescription_position)
         {
            for ( my $i=0; $i<=$#$fields; $i++ )
            {
               $fields->[$i]->[$levelOfDescription_position] = trimws ($fields->[$i]->[$levelOfDescription_position]);
               $fields->[$i]->[$levelOfDescription_position] = lc ($fields->[$i]->[$levelOfDescription_position]);
            }
         }
         
         # process each line of the file
         for ( my $i=0; $i<=$#$fields; $i++ )
         {
            # add in spreadsheet source
            $fields->[$i]->[$#{$fields->[$i]}+1] = "$offset/$d";

            # find the level of description, defaulting to 'item'
            my $LoD = 'item';
            if (defined $levelOfDescription_position)
            {
               $LoD = $fields->[$i]->[$levelOfDescription_position];
            }   

            # skip view lines
            next if ($LoD eq 'view');

            # create initial filename from counter and assume not fixed id
            my $filename = $counter;
            $counter++;
            my $createUniqueId = '';
            
            # use a fixed identifier if there is one
            if ((defined $fixedidentifier) && ($fixedidentifier ne ''))
            {
               my $identifier_position = getPos ($headings, $fixedidentifier);
               if ((defined $identifier_position) && ($fields->[$i]->[$identifier_position] ne ''))
               {
                  $filename = $fields->[$i]->[$identifier_position];
                  $filename =~ trimws ($filename);
                  $filename =~ s/[^a-zA-Z0-9_\[\]\-\.]/_/go;
                  
                  # set flag to create simple resolver entry
                  $createUniqueId = $filename;
               }
            }
               
            # check for parent entry
            my $qubitParentSlug_position = getPos ($headings, "qubitParentSlug");
            my $parent = undef;
            if ((defined $qubitParentSlug_position) &&
                ($fields->[$i]->[$qubitParentSlug_position] ne '') &&
                (exists $dirBySlug{trimws ($fields->[$i]->[$qubitParentSlug_position])}))
            {
               $parent = $dirBySlug{trimws ($fields->[$i]->[$qubitParentSlug_position])};
            }
            elsif ((defined $parentId_position) &&
                   ($fields->[$i]->[$parentId_position] ne '') &&
                   (exists $dirByLegacy{$fields->[$i]->[$parentId_position]}))
            {
               $parent = $dirByLegacy{$fields->[$i]->[$parentId_position]};
            }
               
            # save parent-child details for deferred generation of index
            if (defined $parent)
            {
               if (! exists $childrenByParent->{$offset.'/'.$parent})
               {
                  $childrenByParent->{$offset.'/'.$parent} = [];
               }
               push (@{$childrenByParent->{$offset.'/'.$parent}}, $filename.'@type@'.$LoD);
            }
            else
            {
               if (! exists $childrenByParent->{$offset})
               {
                  $childrenByParent->{$offset} = [];
               }
               push (@{$childrenByParent->{$offset}}, $filename.'@type@'.$LoD);
            }
            
            # update filename to include parent
            if (defined $parent)
            {
               $filename = $parent.'/'.$filename;
            }
            
            # create simple resolver entry
            if ($createUniqueId ne '')
            {
               createResolver ($resolverDir, $destination, $offset, $filename, $createUniqueId);
            }
               
            # set locations for future child elements
            if ((defined $title_position) &&
                ($fields->[$i]->[$title_position] ne ''))
            {
               my $slug = makeSlug ($fields->[$i]->[$title_position]);
               $dirBySlug{$slug} = $filename;
               # add slug into metadata explicitly
               $fields->[$i]->[$#{$fields->[$i]}+1] = $slug;
            }
            if ((defined $legacyId_position) &&
                ($fields->[$i]->[$legacyId_position] ne ''))
            {
               $dirByLegacy{$fields->[$i]->[$legacyId_position]} = $filename;
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
               # strip prefixes from view locations and check for missing files
               for ( my $k=0; $k<=$#views; $k+=2 )
               {
                  $views[$k+1] =~ s/\/uploads\/fhya\/(.*)/$1/;
                  $views[$k+1] =~ s/\/uploads\/(.*)/$1/;
                  # check that the file exists
                  if (! -e "$renderDir/collection/$views[$k+1]")
                  {
                     print "MISSING FILE: $renderDir/collection/$views[$k+1]\n";
                  }
               }
               $fields->[$i]->[$digitalObjectPath_position] = join ($separatorClean, @views);
            }
            
            # escape unescaped ampersands to avoid being mistaken for attribute specification
            # [hussein, 10 june 2024]
            for ( my $j=0; $j<=$#{$fields->[$i]}; $j++ )
            {
#               if ($fields->[$i]->[$j] =~ /\@/)
#               { print "************* YESBEFORE $fields->[$i]->[$j]\n"; }
#               $fields->[$i]->[$j] =~ s/(?<!\\)\@/\\\@/go;
#               if ($fields->[$i]->[$j] =~ /\@/)
#               { print "************* YESAFTER $fields->[$i]->[$j]\n"; }
            }

            # write XML
            if (($filename ne '') && ((needUpdate (["$source$offset/$d"], ["$destination$offset/$filename/metadata.xml"])) || ($optForce)))
            {
               if (! -e "$destination$offset/$filename")
               {
                  # print "Creating directory $destination$offset/$filename\n";
                  mkdir ("$destination$offset/$filename");
               }
               if (createXML ("$destination$offset/$filename/metadata.xml", substr ("$offset/$filename", 1), "item", $headings, $fields->[$i]))
               {
                  print "METADATA : Generating $LoD $destination$offset/$filename/metadata.xml\n";
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
         importMetadata ($source, $destination, "$offset/$d", $optForce, $resolverDir, $childrenByParent);
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
   
   # added automatic cleanup for microsoft characters
   # [hussein, 10 june 2024]
   # https://stackoverflow.com/questions/4332707/paste-from-ms-word-into-textarea/6219023#6219023
   $value =~ s/[\x{2018}\x{2019}\x{201A}]/'/go;
   $value =~ s/[\x{201C}\x{201D}\x{201E}]/"/go;
   $value =~ s/[\x{2026}]/\.\.\./go;
   $value =~ s/[\x{2013}\x{2014}]/\-/go;
   $value =~ s/[\x{02C6}]/^/go;
   $value =~ s/[\x{02DC}\x{00A0}]/ /go;
   
   return $value;
}

sub URLEscape
{
   my ($value) = @_;
   
   $value =~ s/ /%20/go;
   
   return $value;
}

# create hierarchy of directories
sub makePath
{
   my ($where, $path) = @_;

   my @components = split ('/', $path);
   pop (@components);

   my $runningPath = $where;
   foreach my $comp (@components)
   {
      $runningPath .= '/'.$comp;
      if (! -e $runningPath)
      { 
         mkdir ($runningPath); 
      }
   }
}


sub createXML
{
   my ($filename, $itemlocation, $container, $headings, $values) = @_;

   my $printBuffer = '';   
#   open (my $file, ">:utf8", "$filename");
#   print $file "<$container>\n";
   
   my ($eventActors, $eventTypes, $eventDates, $eventDescriptions, $digitalObjectPath, $creators, $cdate) = ('', '', '', '', '', '', '');
   my $title = '';
   
   my $entityFieldX = 'creator';
   if ((defined $entityField) && ($entityField ne ''))
   { $entityFieldX = $entityField; }
    
   for ( my $i=0; $i<=$#$headings; $i++ )
   {
      my $heading = $headings->[$i];

      # trim start and end spaces in tag name
      $heading = trimws ($heading);

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
      elsif ($heading eq $entityFieldX)
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
               # changed simple split to one that ignores escaped characters and then removes escapes characters
               # after split, \@ becomes @ and \\ becomes \ 
               # [hussein 17 feb 2023]
               my @valueattrbit = (map { s/\\([\\@])/$1/g; $_; } ($value_bit =~ /(?:^|\@) ((?:\\[\\@] | [^\@])*)/gx));
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
                  $value_bit = trimws ($value_bit);
                  if ($heading ne '')
                  {
                     $printBuffer .= "   <$heading$attributes>\n";
                  }
                  foreach my $value_bit2 (split ($separator2, $value_bit))
                  {
                     if ($heading eq 'relatedUnitsOfDescription')
                     {
                        $printBuffer .= "      <$subfieldIndicator>".XMLEscape (URLEscape ($value_bit2))."</$subfieldIndicator>\n";
                     }
                     elsif ($heading ne '')
                     {
                        $printBuffer .= "   <$subfieldIndicator>".XMLEscape ($value_bit2)."</$subfieldIndicator>\n";
                        if ($heading eq 'title')
                        { $title = XMLEscape ($value_bit2); }
                        if ($heading eq 'date')
                        { $cdate = XMLEscape ($value_bit2); }
                     }
                     $subfieldIndicator++;
                  } 
                  if ($heading ne '')
                  {
                     $printBuffer .= "   </$heading>\n";
                  }
               } 
               else
               {
                  $value_bit = trimws ($value_bit);
                  if ($heading eq 'relatedUnitsOfDescription')
                  {
                     $printBuffer .= "   <$heading$attributes>".XMLEscape ($value_bit)."</$heading>\n";
#                     print $file "   <$heading$attributes>".XMLEscape (URLEscape ($value_bit))."</$heading>\n";
                  }
                  elsif ($heading ne '')
                  {
                     $printBuffer .= "   <$heading$attributes>".XMLEscape ($value_bit)."</$heading>\n";
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

   my @eventActors_list = split ($separator, XMLEscape ($eventActors));
   my @eventTypes_list = split ($separator, XMLEscape ($eventTypes));
   my @eventDates_list = split ($separator, XMLEscape ($eventDates));
   my @eventDescriptions_list = split ($separator, XMLEscape ($eventDescriptions));
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
         $printBuffer .= "   <event>\n".
                     "      <eventActor$actorId>$eventActors_list[$i]</eventActor>\n".
                     "      <eventType>$eventTypes_list[$i]</eventType>\n".
                     "      <eventDate>$eventDates_list[$i]</eventDate>\n".
                     "      <eventDescription>$eventDescriptions_list[$i]</eventDescription>\n".
                     "   </event>\n";
      }
   }
   
   # process creators (aka entityFieldX) as entities and add IDs to each
   my @creators_list = split ($separator, XMLEscape ($creators));
   for ( my $i = 0; $i <= $#creators_list; $i++ )
   {
      my $actorId = '';
      if ($itemlocation ne '')
      { 
         $actorId = addEntityItemRole ($creators_list[$i], $itemlocation, $title, 'author', $cdate);
         $actorId = " id=\"internal$actorId\""; 
      }
      $printBuffer .= "   <$entityFieldX$actorId>$creators_list[$i]</$entityFieldX>\n";
   }

#print "***".$digitalObjectPath."\n";
   my @digitalObjectPath_list = split ($separator, XMLEscape ($digitalObjectPath));
   for ( my $i = 0; $i <= $#digitalObjectPath_list; $i+=2 )
   {
      $digitalObjectPath_list[$i] = trimws ($digitalObjectPath_list[$i]);
      $digitalObjectPath_list[$i+1] = trimws ($digitalObjectPath_list[$i+1]);
      
      # create stub with page number if thumbnail must rely on non-first page
      if ($digitalObjectPath_list[$i+1] =~ /^((.*)\/)?(.*\.pdf)\[([0-9]+)\]$/)
      {
         $digitalObjectPath_list[$i+1] = $1.$3;
         my $displayPage = $4 - 1;
         makePath ("$renderDir/thumbs", $2);
         open ( my $f2, ">$renderDir/thumbs/$1$3.page" );
         print $f2 $displayPage."\n";
         close ($f2);         
      }
      
      $printBuffer .= "   <view>\n".
                  "      <title>$digitalObjectPath_list[$i]</title>\n".
                  "      <file>".URLEscape ($digitalObjectPath_list[$i+1])."</file>\n".
                  "   </view>\n";
   }

   # only write file if it has changed
   $printBuffer = "<$container>\n$printBuffer</$container>\n";
   open (my $filein, "<:utf8", "$filename");
   my $checkdata = do { local $/=undef; <$filein> };
   close ($filein);
   if ($checkdata ne $printBuffer)
   {
      open (my $fileout, ">:utf8", "$filename");
      print $fileout $printBuffer;
      close ($fileout);
      return 1;
   }   
   return 0;
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
   my ($source, $destination, $offset, $level, $optForce) = @_;

   # get list of uploads
   opendir (my $dir, $source.$offset);
   my @uploads = readdir ($dir);
   closedir ($dir);
   @uploads = grep { !/^\./ } @uploads;
   @uploads = grep { !/\~$/ } @uploads;
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
         my $innerType = importUploads ($source, $destination, $offset.'/'.$u, $level+1, $optForce);
         print $ifile "<item type=\"$innerType\">$u</item>\n";
      }
      else
      {
         # create metadata file
         if ((needUpdate (["$source$offset/$u"], ["$destination$offset/$u"])) || ($optForce))
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
      importDir ($spreadsheetDir, $metadataDir, $optForce, $resolverDir);
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
      importUploads ($uploadDir, "$metadataDir/$uploadMetadataLocation", '', 2, $optForce);
      print "\n";
   }
   
   print "SimpleDL: Import Complete\n\n";
}

main ();


