#!/usr/bin/perl
#
# Add a comment to an item, add an item, add a user
# Hussein Suleman
# 8 December 2020

use CGI;
use POSIX qw(strftime);
use IO::File;
use IO::Handle;

do './common.pl';

# get CGI variables
my $cgi = new CGI;
my $comment = $cgi->param ('commentbox');
my $item = $cgi->param ('item');
my $user = $cgi->param ('user');
my $userID = $cgi->param ('userID');
my $email = $cgi->param ('email');
my $url = $cgi->param ('url');
my $date = strftime "%FT%T%z", localtime;
my $cafile = $cgi->upload ('cafile');
my $cafilename = $cgi->param ('cafile');
my $motivation = $cgi->param ('motivation');
my $fullmetadata = $cgi->param ('fullmetadata');

# decide on what kind of contribution this is
my $gotAttachment = 0;
if ((defined $cafile) && ($cafilename ne ''))
{ $gotAttachment = 1; }
my $gotComment = 0;
if ($item ne '')
{ $gotComment = 1; }

# sanitize filename
$cafilename =~ s/[^a-zA-Z0-9_\.]//go;

# check directories
if (! -e $moderationDir)
{ mkdir ($moderationDir); }

# get ID for new moderation activity
sub getModerationID
{
   my $moderationNumber = getID ('moderation');
   mkdir ($moderationDir."/$moderationNumber");
   mkdir ($moderationDir."/$moderationNumber/data");
   $moderationNumber;
}

# user
if ($motivation ne '')
{
   my $moderationID = getModerationID ();
   open ( my $cfile, '>'.$moderationDir."/$moderationID/object.xml");
   print $cfile "<object>\n".
                "<type>user</type>\n".
                "<email>$email</email>\n".
                "<user>$user</user>\n".
                "<motivation>$motivation</motivation>\n".
                '</object>';
   close ($cfile);
   
   open ( my $hfile, "header.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   $header =~ s/\<\/body\>.*\<\/html\>//s;
   
   print $cgi->header;
   print $header;

   print "<h1>New User Application</h1>\n".
         "<p>Thank you for your request.  A moderator will consider this as soon as possible and you will hear back from us.</p>\n".
         "</body></html>";

   sendAdminEmail ("New user application - $email", 
     "User - $user\nEmail - email\nMotivation - $motivation\n\nLog into the site to approve/deny this request\n");
}
# not a user - login required
else
{
   # check for login
   # create login verification token
   my $verifyCheck = '';
   srand ($userID+$verifySalt); 
   for ( my $i=0; $i<20; $i++ )
   { $verifyCheck .= int(rand(10)); }
   # perform verification check, delay and quit if no match
   my $verify = $cgi->cookie ('verify');
   if (($verify ne $verifyCheck))
   {
      sleep (3);
   
      open ( my $hfile, "header.html");
      my @lines = <$hfile>;
      close ($hfile);
      my $header = join ('', @lines);
      print $cgi->header;
      print $header;
#      print $verify.' '.$verifyCheck;
      exit;
   }   

   # comment only - no attachment
   if (($gotComment == 1) && ($gotAttachment == 0))
   {
      my $moderationID = getModerationID ();
      open ( my $cfile, '>'.$moderationDir."/$moderationID/object.xml");
      print $cfile "<object>\n".
                   "<type>comment</type>\n".
                   "<userID>$userID</userID>\n".
                   "<location>$item</location>\n".
                   '<date>'.$date.'</date>'.
                   '<name>'.$user.'</name>'.
                   '<content>'.$comment.'</content>'.
                   '</object>';
      close ($cfile);
      
      thanks ();

      sendAdminEmail ("New comment - $user", 
        "User - $user\nItem - $item\nComment - $comment\n\nLog into the site to approve/deny this request\n");
   }

   # comment plus attachment
   elsif (($gotComment == 1) && ($gotAttachment == 1))
   {
      my $moderationID = getModerationID ();
      open ( my $cfile, '>'.$moderationDir."/$moderationID/object.xml");
      print $cfile "<object>\n".
                   "<type>commentattachment</type>\n".
                   "<userID>$userID</userID>\n".
                   "<location>$item</location>\n".
                   "<filename>$cafilename</filename>\n".
                   '<date>'.$date.'</date>'.
                   '<name>'.$user.'</name>'.
                   '<content>'.$comment.'</content>'.
                   $fullmetadata.
                   '</object>';
      close ($cfile);

      my $buffer;
      open ( my $outfile, '>'.$moderationDir."/$moderationID/data/$cafilename");
      while ( my $bytesread = $cafile->handle->read ($buffer, 1024) ) {
         print $outfile $buffer;
      }
      close ($outfile);
      
      thanks ();

      sendAdminEmail ("New comment and file - $user", 
        "User - $user\nItem - $item\nComment - $comment\n\nLog into the site to approve/deny this request\n");
   }

   # uploaded file
   elsif (($gotComment == 0) && ($gotAttachment == 1))
   {
      my $moderationID = getModerationID ();
      open ( my $cfile, '>'.$moderationDir."/$moderationID/object.xml");
      print $cfile "<object>\n".
                   "<type>upload</type>\n".
                   "<userID>$userID</userID>\n".
                   "<filename>$cafilename</filename>\n".
                   '<date>'.$date.'</date>'.
                   '<name>'.$user.'</name>'.
                   $fullmetadata.
                   '</object>';
      close ($cfile);

      my $buffer;
      open ( my $outfile, '>'.$moderationDir."/$moderationID/data/$cafilename");
      while ( my $bytesread = $cafile->handle->read ($buffer, 1024) ) {
         print $outfile $buffer;
      }
      close ($outfile);
      
      thanks ();

      sendAdminEmail ("New file - $user", 
        "User - $user\nFilename - $cafilename\n\nLog into the site to approve/deny this request\n");
   }

   # print out an error message // redirect to reload page
   # elsif (($gotComment == 0) && ($gotAttachment == 0))
   else
   {
      open ( my $hfile, "header.html");
      my @lines = <$hfile>;
      close ($hfile);
      my $header = join ('', @lines);
      $header =~ s/\<\/body\>.*\<\/html\>//s;
      
      print $cgi->header;
      print $header;
      print "<h1>Error!</h1>\n".
            "<p>You submitted an empty contribution or missing file upload.  Please go back and check.</p>\n".
            "</body></html>";

   #   print $cgi->header.
   #   "<html><body>".
   #   "</body></html>";
   #   print $cgi->redirect ($url);
   }

}   

sub thanks
{
   open ( my $hfile, "header.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   $header =~ s/\<\/body\>.*\<\/html\>//s;
   
   print $cgi->header;
   print $header;
   print "<h1>Thank you!</h1>\n".
         "<p>Thank you for your contribution.  A moderator will consider this as soon as possible.</p>\n".
         "</body></html>";
}

