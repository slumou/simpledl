#!/usr/bin/perl

# SimpleDL: generate website from metadata
# Hussein Suleman
# 18 Jan 2021

$| = 1;

use POSIX;
use XML::DOM;
use Getopt::Long;
use File::Copy "cp";
use FileHandle;

use FindBin;
use lib "$FindBin::Bin";
use EntityManager qw (:DEFAULT);
use CSV qw (:DEFAULT);

do "$FindBin::Bin/../../data/config/config.pl";

use XML::LibXSLT;
use XML::LibXML;
my $xslt = XML::LibXSLT->new();
my $styleDoc = XML::LibXML->load_xml(location=>$mainstylesheet, no_cdata=>1);
my $styleObj = $xslt->parse_stylesheet($styleDoc);


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


# convert config.pl to config.xml
sub generateConfigXML
{
   my () = @_;
   
   open (my $configxml, ">$renderDir/config/config.xml");
   print $configxml "<config>\n";

   foreach my $toplevel ( keys %{$indexers} )
   {
      print $configxml "<toplevel id=\"$toplevel\">\n";      
      print $configxml "   <field_search>\n";
      foreach my $i ( keys %{$indexers->{$toplevel}->{'field_search'}} )
      {
         print $configxml "      <field><id>$i</id><location>$indexers->{$toplevel}->{'field_search'}->{$i}</location></field>\n";
      }
      print $configxml "   </field_search>\n";
      print $configxml "   <field_browse>\n";
      foreach my $i ( @{$indexers->{$toplevel}->{'field_browse'}} )
      {
         print $configxml "      <field><id>$i->[0]</id>";
         print $configxml "<name>$i->[1]</name>";
         for ( my $j=2; $j<=$#{$i}; $j++ )
         {
            print $configxml "<location>$i->[$j]</location>";
         }
         print $configxml "</field>\n";
      }
      print $configxml "   </field_browse>\n";
      print $configxml "   <field_sort>\n";
      foreach my $i ( @{$indexers->{$toplevel}->{'field_sort'}} )
      {
         print $configxml "      <field>$i</field>\n";
      }
      print $configxml "   </field_sort>\n";
      print $configxml "   <field_index>\n";
      foreach my $i ( @{$indexers->{$toplevel}->{'field_index'}} )
      {
         print $configxml "      <index><id>$i->[0]</id><name>$i->[1]</name><location>$i->[2]</location></index>\n";
      }
      print $configxml "   </field_index>\n";
      print $configxml "</toplevel>\n";
   }   
   print $configxml "</config>";
}

# check for acceptable filename for thumbnails
sub isAcceptedFilename
{
   my ($filename) = @_;
   my %accepts = map { $_, 1 } @upload_accept;
   $filename = substr ($filename, rindex ($filename, '.')+1);
   return $accepts{$filename};
}

# create thumbnails if needed
sub generateThumbs
{
   my ($source, $dest, $optForce) = @_;
   
   opendir (my $sdir, $source);
   my @files = readdir ($sdir);
   closedir ($sdir);
   @files = grep { !/^\./ } @files;
   
   mkdir ($dest);

   foreach my $afile (@files)
   {
      if (-d "$source/$afile")
      {
         generateThumbs ($source.'/'.$afile, $dest.'/'.$afile, $optForce);
      }
      # if the file does not exist and is acceptable or
      # the age of the thumb is greater than the age of the file
      elsif ((! -e "$dest/$afile.jpg")
             ||
             (-M "$dest/$afile.jpg" > -M "$source/$afile")
             ||
             ((-e "$dest/$afile.page") && (-M "$dest/$afile.jpg" > -M "$dest/$afile.page"))
             ||
             ($optForce)
            )
      {
         print "Creating thumbnail for $source/$afile\n";
         my $filename = "$source/$afile";
         if (isAcceptedFilename ($afile))
         {
            # switch to fixed thumbnails for some files
            if ($filename =~ /\.[Zz][Ii][Pp]$/)
            { $filename = "$renderDir/images/zipicon.png"; }
            elsif ($filename =~ /\.[Mm][Pp][3]$/)
            { $filename = "$renderDir/images/audioicon.png"; }
            elsif ($filename =~ /\.[Pp][Pp][Tt]$/)
            { $filename = "$renderDir/images/ppticon.png"; }
         }
         else
         # use a generic icon for unrecognised files
         {
            $filename = "$renderDir/images/document.png";
         }
         # get page number for thumbnail if it is set
         my $pageNumber = 0;
         if (-e "$dest/$afile.page")
         {
            open ( my $f, "$dest/$afile.page");
            $pageNumber = <$f>;
            chomp $pageNumber;
            close ($f);
         }
         # create thumbnail 
         my $command = "convert -define jpeg:size=200x200 ".
               "\'$filename\'"."[$pageNumber] ".                  
               "-thumbnail '200x200>' -background white -gravity center -extent 200x200 ".
               "\'$dest/$afile.jpg\' 2\>/dev/null";
         system ($command);
   #     print $command."\n";
      }
   }
}

# create composite thumbnails if needed
sub generateCompositeThumbs
{
   my ($source, $offset, $optForce) = @_;
   
   opendir (my $sdir, "$source$offset");
   my @files = readdir ($sdir);
   closedir ($sdir);
   @files = grep { !/^\./ } @files;
   
   foreach my $afile (@files)
   {
      if (-d "$source$offset/$afile")
      {
         generateCompositeThumbs ($source, $offset.'/'.$afile, $optForce);
      }
      elsif ($afile =~ /index\.[xX][mM][lL]$/)
      {
         my $parser = new XML::DOM::Parser;
         my $doc = $parser->parsefile ("$source$offset/$afile");
         
         foreach my $type ($doc->getElementsByTagName ('type'))
         {
            if (($type->hasChildNodes) && ($type->getFirstChild->toString eq 'file'))
            {
               # gather the full list of first item thumbnails
               my @thumbs = ();
               foreach my $item ($doc->getElementsByTagName ('item'))
               {
                  if (($item->hasChildNodes) && ($item->getAttribute ('type') eq 'item'))
                  {
                     my $itemId = $item->getFirstChild->toString;
                     my $itemdoc = $parser->parsefile ("$source$offset/$itemId/metadata.xml");
                     
                     foreach my $view ($itemdoc->getElementsByTagName ('view'))
                     {
                        foreach my $viewfile ($view->getElementsByTagName ('file'))
                        {
                           if ($viewfile->hasChildNodes)
                           { 
                              my $tfilename = $viewfile->getFirstChild->toString;
                              $tfilename =~ s/^\s+|\s+$//g;
                              # un=URL-escape filename
                              $tfilename =~ s/\%20/ /g;
                              push (@thumbs, $tfilename);
                           }
                        }
                     }
                  }
               }
               
               # regenerate if composite does not exist or if newer thumbnails exist
               my $needupdate = 0;
               if (! -e "$source$offset/thumbnail.jpg")
               { $needupdate = 1; }
               else
               {
                  foreach my $thumb (@thumbs)
                  {
                     if ((-e "$renderDir/thumbs/$thumb.jpg") && 
                         (-M "$source$offset/thumbnail.jpg" > -M "$renderDir/thumbs/$thumb.jpg"))
                     {
                        $needupdate = 1;
                     }
                  }
               }

               if (($needupdate == 1) || ($optForce))
               { 
#               print join ("\n", @thumbs);

                  #print "Generating composite thumbnail: $source$offset\n";
                  my $command = "convert -type TrueColor -size 200x200 xc:grey ".
                                "\'$source$offset/thumbnail.jpg\' 2\>/dev/null";
                  if (($#thumbs == 0) && (-e "$renderDir/thumbs/$thumbs[0].jpg"))
                  {
                     $command = "convert -type TrueColor -size 200x200 xc:grey ".
                                   "\'$renderDir/thumbs/$thumbs[0].jpg\' ".
                                   "-geometry 196x196+2+2 -composite ".
                                   "\'$source$offset/thumbnail.jpg\' 2\>/dev/null";
                  }
                  elsif (($#thumbs == 1) && (-e "$renderDir/thumbs/$thumbs[0].jpg") 
                                         && (-e "$renderDir/thumbs/$thumbs[1].jpg"))
                  {
                     $command = "convert -type TrueColor -size 266x200 xc:grey ".
                                   "\'$renderDir/thumbs/$thumbs[0].jpg\' ".
                                   "-geometry 196x196+2+2 -composite ".
                                   "\'$renderDir/thumbs/$thumbs[1].jpg\' ".
                                   "-geometry 64x64+200+2 -composite ".
                                   "\'$source$offset/thumbnail.jpg\' 2\>/dev/null";
                  }
                  elsif (($#thumbs == 2) && (-e "$renderDir/thumbs/$thumbs[0].jpg") 
                                         && (-e "$renderDir/thumbs/$thumbs[1].jpg")
                                         && (-e "$renderDir/thumbs/$thumbs[2].jpg"))
                  {
                     $command = "convert -type TrueColor -size 266x200 xc:grey ".
                                   "\'$renderDir/thumbs/$thumbs[0].jpg\' ".
                                   "-geometry 196x196+2+2 -composite ".
                                   "\'$renderDir/thumbs/$thumbs[1].jpg\' ".
                                   "-geometry 64x64+200+2 -composite ".
                                   "\'$renderDir/thumbs/$thumbs[2].jpg\' ".
                                   "-geometry 64x64+200+68 -composite ".
                                   "\'$source$offset/thumbnail.jpg\' 2\>/dev/null";
                  }
                  elsif (($#thumbs > 2) && (-e "$renderDir/thumbs/$thumbs[0].jpg") 
                                         && (-e "$renderDir/thumbs/$thumbs[1].jpg")
                                         && (-e "$renderDir/thumbs/$thumbs[2].jpg"))
                  {
                     $command = "convert -type TrueColor -size 266x200 xc:grey ".
                                   "\'$renderDir/thumbs/$thumbs[0].jpg\' ".
                                   "-geometry 196x196+2+2 -composite ".
                                   "\'$renderDir/thumbs/$thumbs[1].jpg\' ".
                                   "-geometry 64x64+200+2 -composite ".
                                   "\'$renderDir/thumbs/$thumbs[2].jpg\' ".
                                   "-geometry 64x64+200+68 -composite ".
                                   "-fill white -pointsize 40 -gravity center -draw 'text 100,66 +' -font Arial ".
                                   "\'$source$offset/thumbnail.jpg\' 2\>/dev/null";
                  }
                  if ($command ne '')
                  {
                     print "Generating composite thumbnail: $source$offset\n";
#                     print $command."\n";
                     system ($command);
                  }   
               }
            }
         }         
      }         
   }
}   


# transform XML files into fhya format
sub transform
{
   my ($stylesheet, $source, $destination, $renderDir, $item, $basedir, $commentRenderDir) = @_;

   # external system call
#   system ("$xsltproc --stringparam \'Xbaserealdir\' \'$renderDir\' ".
#           " --stringparam \'item\' \'$item\' ".
#           " --stringparam \'basedir\' \'$basedir\' ".
#           " --stringparam \'commentRenderDir\' \'$commentRenderDir\' ".           
#           " $stylesheet \'$source\' > \'$destination\'");

   # library call
   my $source = XML::LibXML->load_xml ( location => $source );
   my $results = $styleObj->transform ($source, 
      XML::LibXSLT::xpath_to_string (
         Xbaserealdir => $renderDir,
         item => $item,
         basedir => $basedir,
         commentRenderDir => $commentRenderDir 
      )
   ); 
   open ( my $ofile, ">:utf8", "$destination");
   print $ofile $styleObj->output_as_chars($results);
   close ($ofile);
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

# create dummy files if they do not exist (to prevent XSLT errors)
sub generateItemStubs
{
   my ($item) = @_;
    
   # generate dummy comments files
   my $commentfilename = $commentRenderDir.'/'.$item.'/metadata.xml';
   if (! -e $commentfilename)
   {
      print "Generating stub $commentfilename\n";
      makePath ($commentRenderDir, $item.'/metadata.xml');
      open (my $dummy, ">$commentfilename");
      print $dummy "<comments></comments>\n";
      close ($dummy);
   }
}

# generate all metadata HTML files
sub generateDir
{
   my ($source, $offset, $basedir, $commentRenderDir, $optForce) = @_;
   
   opendir (my $sdir, "$source$offset");
   my @files = readdir ($sdir);
   closedir ($sdir);
   @files = grep { !/^\./ } @files;
   
   foreach my $afile (@files)
   {
      if (-d "$source$offset/$afile")
      {
         generateDir ($source, $offset.'/'.$afile, $basedir.'../', $commentRenderDir, $optForce);
      }
      elsif ($afile =~ /(.*)\.[xX][mM][lL]$/)
      {
         my $filename = $1;
         if ($filename eq 'index')
         {
            my $item = substr ("$offset", 1);
            generateItemStubs ($item);
            if (needUpdate (["$source/$item/index.xml", "$source/$item/metadata.xml", $mainstylesheet], ["$source/$item/index.html"]) || ($optForce))
            {
               print "Transforming $source/$item xml->html\n";
               transform ($mainstylesheet, "$source/$item/index.xml", "$source/$item/index.html", 
                          $renderDir, $item, $basedir, $commentRenderDir);
            }              
         }
      }         
   }
}

# generate all website HTML files
sub generateHTML
{
   my ($source, $offset, $basedir, $recursive, $optForce, $commentRenderDir) = @_;
   
   opendir (my $sdir, "$source$offset");
   my @files = readdir ($sdir);
   closedir ($sdir);
   @files = grep { !/^\./ } @files;
   
   foreach my $afile (@files)
   {
      if (($recursive == 1) && (-d "$source$offset/$afile"))
      {
         generateHTML ($source, $offset.'/'.$afile, $basedir.'../', $recursive, $optForce, $commentRenderDir);
      }
      elsif ($afile =~ /(.*)\.[xX][mM][lL]$/)
      {
         my $filename = $1;
         if (($filename ne 'config') &&
             (needUpdate (["$source$offset/$afile", $mainstylesheet], ["$source$offset/$filename.html"]) || ($optForce == 1)) 
            )
         {
            print "Transforming $source$offset/$afile xml->html\n";
            transform ($mainstylesheet, "$source$offset/$afile", "$source$offset/$filename.html", 
                       $renderDir, '', $basedir, $commentRenderDir);
         }
      }         
   }
}

# recursive copy of files
sub recursiveCopy
{
   my ($source, $destination) = @_;
   
   if (! -d $source)
   {
      # file
#         print "Checking $source to $destination".(-M $destination)." ".(-M $source)."\n";
      if ((! -e $destination) || (-M $destination > -M $source))
      {
         print "Copying $source to $destination\n";
         my $f = FileHandle->new ($source, "r");
         binmode $f;
         cp ($f, $destination);
         # make sure files in cgi are not writable by others
         if ($destination =~ /cgi-bin/)
         {
            system ("chmod go-w $destination");
         }
      }   
   }
   else
   {
      # directory
      if (! -e $destination)
      {
         print "Making directory $destination\n";
         mkdir ($destination);
         # make sure cgi directory is not readable
         if ($destination =~ /cgi-bin/)
         {
            system ("chmod 711 $destination");
         }         
      }
      opendir (my $sdir, "$source");
      my @files = readdir ($sdir);
      closedir ($sdir);
      foreach my $f ( grep { !/^\./ } @files )
      {
         recursiveCopy ($source.'/'.$f, $destination.'/'.$f);
      }
   }
}

# generate website, importing files as needed
sub generateWebsite
{
   my ($renderDir, $templateDir, $optForce, $commentRenderDir) = @_;
   
   # copy across all template files
   foreach my $template (@$templateLocations)
   {
      my ($source, $destination) = ($template->[0], $template->[1]);
      print "Replicating $source --> $destination\n";
      recursiveCopy ($source, $destination);
   }
   
   # convert xml to html
   generateHTML ($renderDir, '', '', 0, $optForce, $commentRenderDir);
   
   # create headers for scripts
   if (needUpdate (["$cgiDir/header.xml", $mainstylesheet], ["$cgiDir/header.html"]) || ($optForce == 1))
   {
      print "Updating header.html\n";
      transform ($mainstylesheet, "$cgiDir/header.xml", "$cgiDir/header.html", $renderDir, '', '../', $commentRenderDir);
   }
   if (needUpdate (["$cgiDir/adminheader.xml", $mainstylesheet], ["$cgiDir/adminheader.html"]) || ($optForce == 1))
   {
      print "Updating adminheader.html\n";
      transform ($mainstylesheet, "$cgiDir/adminheader.xml", "$cgiDir/adminheader.html", $renderDir, '', '../', $commentRenderDir);
   }
   if (needUpdate (["$cgiDir/popupheader.xml", $mainstylesheet], ["$cgiDir/popupheader.html"]) || ($optForce == 1))
   {   
      print "Updating popupheader.html\n";
      transform ($mainstylesheet, "$cgiDir/popupheader.xml", "$cgiDir/popupheader.html", $renderDir, '', '../', $commentRenderDir);
   }
}

sub generateUsers
{
   my ($userRenderDir, $renderDir, $commentRenderDir, $optForce) = @_;

   # get list of users
   opendir (my $dir, $userRenderDir);
   my @users = readdir ($dir);
   closedir ($dir);
   @users = grep { /^[a-zA-Z0-9_]+\.xml$/ } @users;

   foreach my $user (@users)
   {
      $user = substr ($user, 0, -4);
      # create user html
      if ((-e "$userRenderDir/$user.xml") && 
          (( -M "$userRenderDir/$user.html" > -M "$userRenderDir/$user.xml" ) ||
           (! -e "$userRenderDir/$user.html") ||
           ($optForce == 1)))
      {
         print "Generating user $user\n";         
         transform ($mainstylesheet, "$userRenderDir/$user.xml", 
                    "$userRenderDir/$user.html", $renderDir,
                    '', '../', $commentRenderDir);
      }
   }   
}

sub URL_escape
{
   my ($value) = @_;
   $value =~ s/ /%20/go;
   return $value;
}


# generate a single page through a transform
sub generatePage
{
   my ($location, $renderDir, $commentRenderDir) = @_;

   # single item file regeneration
   if ($location ne '')
   {
      if (-e "$renderDir/$location.xml")
      {
         print "Found item\n";
         my $item = '';
         my $basedir = $location;
         if ($location =~ /(metadata\/(.*)\/)index/)
         { 
            $item = $2; 
            $basedir = $1;
         }
         $basedir =~ s/[^\/]//go;
         $basedir =~ s/\//\.\.\//go;
#print $basedir;
#         if (substr ($item, -5) eq 'index')
#         { $item = substr ($item, 0, -6); }
         
#         create_thumbs ("$renderDir/collection", "$renderDir/thumbs");
         transform ($mainstylesheet, "$renderDir/$location.xml",
                    "$renderDir/$location.html", $renderDir, 
                    $item, $basedir, $commentRenderDir);
      }
   }
}   


# main program body
sub main 
{
   my ($optForce, $optHelp, $optConfig, $optPage, $optDir, $optThumbs, $optComposite, $optUsers, $optWebsite, $optAll) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
   my $optionsOK = GetOptions ('help|?' => \$optHelp, 
                               'config' => \$optConfig,
                               'page=s' => \$optPage,
                               'dir' => \$optDir,
                               'thumbs' => \$optThumbs,
                               'composite' => \$optComposite,
                               'users' => \$optUsers,
                               'website' => \$optWebsite,
                               'all' => \$optAll,
                               'force' => \$optForce
                               );
   
   # if error or help asked for
   if (($optionsOK == 0) || ($optHelp == 1))
   {
      print <<EOC;
generate.pl [options]

Options:
 --help       this information
 --config     generate configuration file
 --page n     generate single page using XSLT
 --dir        generate all metadata pages (default if no options specified)
 --thumbs     generate thumbnails
 --composite  generate composite thumbnails
 --users      generate users
 --website    generate website framework, and copy template files
 --all        full site regeneration
 --force      force regeneration of all pages
EOC
      return;
   }

   print "SimpleDL: Generate HTML files\n\n";

   # if no options, default to processing only metadata
   if (($optHelp == 0) && ($optConfig == 0) && (! $optPage) && ($optDir == 0) && ($optThumbs == 0) && ($optComposite == 0) && ($optUsers == 0) && ($optWebsite == 0) && ($optAll == 0))
   {
      $optDir = 1;
   }

   # page should be mutually exclusive with all
   if ($optDir == 1)
   {
      $optPage = 0;
   }   
   # if full regeneration requested, set all options to true
   if ($optAll == 1)
   {
      ($optConfig, $optDir, $optThumbs, $optComposite, $optUsers, $optWebsite) = (1, 1, 1, 1, 1, 1); 
   }

   # check each individual option   
   if ($optConfig == 1) 
   { 
      print "Generating configuration file\n";
      generateConfigXML (); 
      print "\n";
   }
   if ($optDir == 1) 
   { 
      print "Generating metadata directories\n";
      generateDir ($metadataDir, '', '../', $commentRenderDir, $optForce);
      print "\n";
   }
   if ($optThumbs == 1) 
   { 
      print "Generating thumbnails\n";
      generateThumbs ("$renderDir/collection", "$renderDir/thumbs", $optForce); 
      print "\n";
   }
   if ($optComposite == 1) 
   { 
      print "Generating composite thumbnails\n";
      generateCompositeThumbs ($metadataDir, '', $optForce); 
      print "\n";
   }
   if ($optUsers == 1) 
   { 
      print "Generating user profiles\n";   
      generateUsers ($userRenderDir, $renderDir,  $commentRenderDir, $optForce); 
      print "\n";
   }
   if ($optWebsite == 1) 
   { 
      print "Generating website\n";
      generateWebsite ($renderDir, $templateDir, $optForce, $commentRenderDir); 
      print "\n";
   }
   if ($optPage)
   { 
      print "Generating page $optPage\n";
      generatePage ($optPage, $renderDir, $commentRenderDir);
      print "\n";
   }
   
   print "SimpleDL: Generate complete\n\n";

}

main;


