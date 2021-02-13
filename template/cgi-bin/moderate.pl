#!/usr/bin/perl
#
# Service the moderation queue
# Hussein Suleman
# 24 October 2019

use POSIX qw(strftime);
use IO::File;
use IO::Handle;
use XML::DOM;
use XML::DOM::XPath;

do './admin.pl';
do './mime.pl';

#my $uploadMetadataLocation = 'Public Depot';
#my $uploadObjectLocation = 'Public Depot';

# get CGI variables
my $action = $cgi->param ('action');
my $item = $cgi->param ('item');
my $path = $cgi->param ('path');

# possible actions for this script
if ($action eq '')
{ $action = 'list'; }

if ($action eq 'list')
{ 
   listModeration (); 
}
elsif (($action eq 'downloadfile') && ($path ne ''))
{
   downloadFile ($path);
}
elsif (($action eq 'approve') && ($item ne ''))
{
   approveItem ($item);
   print $cgi->redirect ('moderate.pl');
}
elsif (($action eq 'deny') && ($item ne ''))
{
   denyItem ($item);
   print $cgi->redirect ('moderate.pl');
}

exit;

# download a file
sub downloadFile
{
   my ($path) = @_;

   my $filename = $path;
   if ($filename =~ /\/([^\/]+)$/)
   {
      $filename = $1;
   }

   $path = $moderationDir.'/'.$path;

   if (-e $path)
   {
      print "Content-type: ".mime ($path)."\n".
            "Content-Disposition: attachment; filename=$filename;\n".
            "Cache-control: max-age=300, public\n\n";
      open (FILE, $path);
      my @contents = <FILE>;
      print @contents;
      close (FILE);
   }
   else 
   {
      print "Content-type: text/plain\n\nError\n";
   }
}

# extract a single value from an XML tree based on its node's XPath
sub getValues
{
   my ($doc, $expr) = @_;
   my $result = '';
   foreach my $node ($doc->findnodes ('object/'.$expr))
   {
      foreach my $child ($node->getChildNodes)
      {
         $result .= $child->toString;
      }   
   }
   $result;
}

# display the list of items to be moderated
sub listModeration
{
   opendir (my $mdir, $moderationDir);
   my @files = readdir ($mdir);
   closedir ($mdir);
   @files = grep { /[0-9]/ } @files;
   
#   my $moderationtasks = $#files + 1;
   displayAdminHeader (); #"Set-Cookie: moderation=$moderationtasks; Path=/\n");

   print "<h1>List of Moderation Tasks</h1>\n";
   
   if ($#files == -1)
   {
      print "<p>No moderation tasks</p>\n";
   }
   else
   {
      print "<table class=\"moderationtable\">\n".
            "<tr><th>Date/time</th><th>Type</th><th>Details</th><th>Action</th></tr>\n";
      foreach my $task (sort { $a <=> $b } @files)
      {
         my $mfilename = $moderationDir."/$task/object.xml";
         
         if (! -e $mfilename)
         {
            next;
         }
         
         my $dtime = strftime ('%d %b %Y %H:%M:%S', localtime ((stat ($mfilename))[9]));
         my $parser = new XML::DOM::Parser;
         my $doc = $parser->parsefile ($mfilename);

         my $type = getValues ($doc, "type");
         my $row = "<td>$dtime</td>";
         if ($type eq 'user')
         {
            $row .= "<td>User</td>";
            my $muser = getValues ($doc, "user");
            my $memail = getValues ($doc, "email");
            my $mmotivation = getValues ($doc, "motivation");
            $row .= "<td>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Username:</div><div class=\"mttext\">$muser</div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Email:</div><div class=\"mttext\">$memail</div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Motivation:</div><div class=\"mtarea\">$mmotivation</div></div>".
                    "</td>";
         }
         elsif ($type eq 'comment')
         {
            $row .= "<td>Comment</td>";
            my $muserID = getValues ($doc, "userID");
            my $mlocation = getValues ($doc, "location");
            my $mdate = getValues ($doc, "date");
            my $muser = getValues ($doc, "name");
            my $mcontent = getValues ($doc, "content");
            $row .= "<td>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Username:</div><div class=\"mttext\"><a href=\"../users/$muserID.html\">$muser</a></div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Comment on:</div><div class=\"mttext\"><a href=\"../metadata/$mlocation/index.html\">$mlocation</a></div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Comment:</div><div class=\"mtarea\">$mcontent</div></div>".
                    "</td>";
         }
         elsif ($type eq 'commentattachment')
         {
            $row .= "<td>Comment with Attachment</td>";
            my $muserID = getValues ($doc, "userID");
            my $mlocation = getValues ($doc, "location");
            my $mdate = getValues ($doc, "date");
            my $muser = getValues ($doc, "name");
            my $mcontent = getValues ($doc, "content");
            my $mfilename = getValues ($doc, "filename"); 
            my $mmetadata = getValues ($doc, "metadata");
            $mmetadata =~ s/&/&amp;/go;
            $mmetadata =~ s/\</&lt;/go;
            $mmetadata =~ s/\>/&gt;/go;
            $row .= "<td>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Username:</div><div class=\"mttext\"><a href=\"../users/$muserID.html\">$muser</a></div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Comment on:</div><div class=\"mttext\"><a href=\"../metadata/$mlocation/index.html\">$mlocation</a></div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Comment:</div><div class=\"mtarea\">$mcontent</div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Filename:</div><div class=\"mttext\"><a href=\"?action=downloadfile&path=$task/data/$mfilename\">$mfilename</a></div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Metadata:</div><div class=\"mtarea\">$mmetadata</div></div>".
                    "</td>";
         }
         elsif ($type eq 'upload')
         {
            $row .= "<td>Uploaded file</td>";
            my $muserID = getValues ($doc, "userID");
            my $mdate = getValues ($doc, "date");
            my $muser = getValues ($doc, "name");
            my $mfilename = getValues ($doc, "filename");
            my $mmetadata = getValues ($doc, "metadata");
            $mmetadata =~ s/&/&amp;/go;
            $mmetadata =~ s/\</&lt;/go;
            $mmetadata =~ s/\>/&gt;/go;
            $row .= "<td>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Username:</div><div class=\"mttext\"><a href=\"../users/$muserID.html\">$muser</a></div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Filename:</div><div class=\"mttext\"><a href=\"?action=downloadfile&path=$task/data/$mfilename\">$mfilename</a></div></div>".
                    "<div class=\"mtrow\"><div class=\"mtheading\">Metadata:</div><div class=\"mtarea\">$mmetadata</div></div>".
                    "</td>";
         }
         print "<tr>".$row."<td>".
               "<form name=\"actionform1\" class=\"actionformclass\" method=\"post\" action=\"moderate.pl\">".
               "<button id=\"approvebutton1\" class=\"approve-button mdc-button mdc-button--raised\" type=\"submit\"/>".
               "<span class=\"mdc-button__label\">Approve</span></button>".
               "<input type=\"hidden\" name=\"item\" value=\"$task\"/>".
               "<input type=\"hidden\" name=\"action\" value=\"approve\"/>".
               "</form>".
               "<form name=\"actionform2\" class=\"actionformclass\" method=\"post\" action=\"moderate.pl\">".
               "<button id=\"denybutton\" class=\"deny-button mdc-button mdc-button--raised\" type=\"submit\"/>".
               "<span class=\"mdc-button__label\">Deny</span></button>".
               "<input type=\"hidden\" name=\"item\" value=\"$task\"/>".
               "<input type=\"hidden\" name=\"action\" value=\"deny\"/>".
               "</form>".
               "<script>".
               "   mdc.ripple.MDCRipple.attachTo(document.querySelector('.approve-button'));".
               "   mdc.ripple.MDCRipple.attachTo(document.querySelector('.deny-button'));".
               "</script>".         
               "</td></tr>\n";
      }
      print "</table>\n";      
   }
   
   print "</div></body></html>";
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
      { mkdir ($runningPath); }
   }
}

# approve of an item
sub approveItem
{
   my ($item) = @_;

   if ($item ne '')
   {
      my $mfilename = $moderationDir."/$item/object.xml";

      if (! -e $mfilename)
      {
         return;
      }   

      my $parser = new XML::DOM::Parser;
      my $doc = $parser->parsefile ($mfilename);

      my $type = getValues ($doc, "type");

      if ($type eq 'user')
      {
         my $userID = getID ('users');
         my $muser = getValues ($doc, "user");
         my $memail = getValues ($doc, "email");
         my $mmotivation = getValues ($doc, "motivation");
         
         # create user files
         open ( my $cfile, '>'.$userDir."/$userID.name.xml");
         print $cfile "<name>$muser</name>\n";
         close ($cfile);
         open ( my $cfile, '>'.$userDir."/$userID.email.xml");
         print $cfile "<email>$memail</email>\n";
         close ($cfile);
         open ( my $cfile, '>'.$userDir."/$userID.profile.xml");
         print $cfile "<profile> </profile>\n";
         close ($cfile);
         
         # user entry globs
         my $maxuserlen = 6;
         my $maxuserglob = join ('', map { '?' } 1..$maxuserlen);

         # merge user bits into a single file
         system ("echo \'<user><type>$vocab->{'PublicContributor'}</type>\' > $userRenderDir/$userID.xml; ".
           "cat $userDir/$userID.name.xml >> $userRenderDir/$userID.xml 2>/dev/null; ".
           "cat $userDir/$userID.profile.xml >> $userRenderDir/$userID.xml 2>/dev/null; ".
           "cat $userDir/$userID.$maxuserglob.xml >> $userRenderDir/$userID.xml; ".
           "echo \'</user>\' >> $userRenderDir/$userID.xml; ".
           "chmod a+w $userRenderDir/$userID.xml");

         # regenerate user page
         system ("$binDir/generate.pl --page users/$userID >/dev/null");
         
         # move moderation entry
         system ("mv $moderationDir/$item $moderationDir"."-approve/");
      }
      elsif (($type eq 'comment') || 
             ($type eq 'commentattachment') ||
             ($type eq 'upload'))
      {
         my $muserID = getValues ($doc, "userID");
         my $mlocation = getValues ($doc, "location");
         my $mdate = getValues ($doc, "date");
         my $muser = getValues ($doc, "name");
         my $mcontent = getValues ($doc, "content");
         my $attachmentID = '';
         my $attachmentBit = '';
         my $cafilename = getValues ($doc, "filename");
         my $mmetadata = getValues ($doc, "metadata");

         if (($type eq 'commentattachment') || ($type eq 'upload'))
         {
            $attachmentID = getID ('upload');
#            $attachmentBit = '<attachment>'.$attachmentID.'</attachment>';

            # copy attachment file to final location
            mkdir ("$renderDir/collection/$uploadObjectLocation/$attachmentID");
            system ("cp \"$moderationDir/$item/data/$cafilename\" \"$renderDir/collection/$uploadObjectLocation/$attachmentID/\"");
            
            # create metadata entry
            my $related = '';
            if ($type eq 'commentattachment')
            { $related = "<relatedUnitsOfDescription>metadata/$mlocation</relatedUnitsOfDescription>\n"; }

            # check if metadata upload location is a transformed structured location
            my $uploadLocation = '';
            foreach my $ulField ( keys %{$uploadStructure} )
            {
               my $loc = getValues ($doc, 'metadata/'.$ulField);
               $uploadLocation = $uploadStructure->{$ulField}->{$loc};
               if ($uploadLocation)
               { break; }
            }
            if ($uploadLocation)
            {
               $uploadLocation = "$uploadLocation/$attachmentID";
            }   
            else
            {
               $uploadLocation = $attachmentID;
            }
            $attachmentBit = '<attachment>'.$uploadMetadataLocation.'/'.$uploadLocation.'</attachment>';
            
            # create metadata.xml
            makePath ($uploadDir, $uploadLocation.'/metadata.xml');
            open ( my $cfile, ">$uploadDir/$uploadLocation/metadata.xml" );
            print $cfile "<item>\n".
                         $mmetadata.
                         "<event>\n".
                         "<eventActor id=\"$muserID\">$muser</eventActor>\n".
                         "<eventType>Submission</eventType>\n".
                         "<eventDate>$mdate</eventDate>\n".
                         "</event>\n".
                         $related.
                         "<view>\n".
                         "<title>$catitle</title>\n".
                         "<file>$uploadObjectLocation/$attachmentID/$cafilename</file>\n".
                         "</view>\n".
                         "</item>\n";
            close ($cfile);
            #open ( my $cfile, ">$renderDir/metadata/$uploadMetadataLocation/$attachmentID/index.xml" );
            #print $cfile "<collection>\n   <type>item</type>\n   <level>2</level>\n</collection>\n";
            #close ($cfile);
            
            # update index file for uploads
            #opendir (my $dir, "$renderDir/metadata/$uploadMetadataLocation/$uploadLocation/..");
            #my @files = readdir ($dir);
            #closedir ($dir);
            #@files = grep { /[0-9]+/ } @files;
            #open ( my $cfile, ">$renderDir/metadata/$uploadMetadataLocation/$uploadLocation/../index.xml" );
            #print $cfile "<collection>\n<level>1</level>\n";
            #foreach my $file (sort { $b <=> $a } @files)
            #{
            #   print $cfile "<item type=\"item\">".$file."</item>\n";
            #}   
            #print $cfile "</collection>\n";
            #close ($cfile);
            
            # reimport uploaded metadata and recreate indices
            system ("$binDir/import.pl --uploads >/dev/null 2>&1");

            # regenerate uploaded metadata and index file
            system ("$binDir/generate.pl --dir >/dev/null 2>&1");
            system ("$binDir/generate.pl --thumbs >/dev/null 2>&1");
            #system ("$binDir/generate.pl \"metadata/$uploadMetadataLocation/index\" >/dev/null 2>&1");
            #system ("$binDir/generate.pl \"metadata/$uploadMetadataLocation/$attachmentID/index\" >/dev/null 2>&1");
         }

         if (($type eq 'comment') || ($type eq 'commentattachment'))
         {
            # get ID for new comment and reserve spot
            my $maxcommentlen = 6;
            my $maxcommentID = join ('', map { '9' } 1..$maxcommentlen);
            my $maxcommentglob = join ('', map { '?' } 1..$maxcommentlen);
            my $commentID = $maxcommentID;
            while (-e $commentDir."/$mlocation/$commentID.xml")
            { $commentID--; }
         
            # store comment as independent file
            makePath ($commentDir, $mlocation.'/metadata.xml');
            open ( my $cfile, '>'.$commentDir."/$mlocation/$commentID.xml" );
            print $cfile '<comment>'.
                         '<date>'.$mdate.'</date>'.
                         '<name>'.$muser.'</name>'.
                         '<userID>'.$muserID.'</userID>'.
                         '<content>'.$mcontent.'</content>'.
                         $attachmentBit.
                         '</comment>';
            close ($cfile);

            # merge comments into a single file
            #system ("echo \'<comments>\' > \'$commentRenderDir/$mlocation.xml\'; ".
            #        "cat \'$commentDir/$mlocation\'.$maxcommentglob.xml >> \'$commentRenderDir/$mlocation.xml\'; ".
            #        "echo \'</comments>\' >> \'$commentRenderDir/$mlocation.xml\'; ".
            #        "chmod a+w \'$commentRenderDir/$mlocation.xml\'");
            system ("$binDir/import.pl --comments >/dev/null 2>&1");

            # regenerate page
            system ("$binDir/generate.pl --page \"metadata/$mlocation/index\" >/dev/null 2>&1");
         }

         # move moderation entry
         system ("mv $moderationDir/$item $moderationDir"."-approve/");
      }
   }   
}

# remove item from moderation queue
sub denyItem
{
   my ($item) = @_;

   system ("mv $moderationDir/$item $moderationDir"."-deny/");
}

