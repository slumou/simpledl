#!/usr/bin/perl
#
# Edit a user profile
# Hussein Suleman
# 17 June 2019

use CGI;
use POSIX qw(strftime);

do './common.pl';

# get CGI variables
my $cgi = new CGI;                        
my $userID = $cgi->param ('userID');
my $profile = $cgi->param ('profile');

# get the user login details
my $verify = $cgi->cookie ('verify');
my $loggedinuserID = $cgi->cookie ('userID');
# create login verification token
my $verifyCheck = '';
srand ($loggedinuserID+$verifySalt); 
for ( my $i=0; $i<20; $i++ )
{ $verifyCheck .= int(rand(10)); }

# perform verification check, delay and quit if no match
if (($verify ne $verifyCheck) || ($userID ne $loggedinuserID))
{
   sleep (60);
   print "Content-type:text/plain\n\n";
   exit;
}

# generate editing form
if ($profile eq '')
{
   if (-e $userDir."/$userID.profile.xml")
   {
      open ( my $pfile, $userDir."/$userID.profile.xml");
      my @lines = <$pfile>;
      close ($pfile);
      $profile = join ('', @lines);
      if ($profile =~ /\<profile\>(.+)\<\/profile\>/s)
      {
         $profile = $1;
      }
   }
   
   open ( my $hfile, "header.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   $header =~ s/\<\/body\>.*\<\/html\>//s;
   
   print $cgi->header;
   print $header;
   print "<div class=\"editprofile\" id=\"editprofile\">\n".
         "<form name=\"editprofileform\" class=\"editprofileformclass\" method=\"post\" action=\"editprofile.pl\">\n".
         "<input type=\"hidden\" name=\"userID\" value=\"$userID\">\n".
         "<div class=\"mdentryfieldbox\"><div class=\"mdentryfield\">\n".
         "<label class=\"mdc-text-field mdc-text-field--textarea mdc-text-field--outlined mdc-text-field--label-floating editprofileboxclass\">\n".
         "<span class=\"mdc-text-field__ripple\"></span>".
         "<textarea id=\"profilebox\" name=\"profile\" class=\"mdc-text-field__input\" rows=\"20\" cols=\"80\" aria-labelledby=\"editprofileboxs\">$profile</textarea>\n".
         "<span class=\"mdc-notched-outline\">\n".
         "<span class=\"mdc-notched-outline__leading\"></span>\n".
         "<span class=\"mdc-notched-outline__notch\"><span id=\"editprofileboxs\" class=\"mdc-floating-label mdc-floating-label--float-above\">Enter/update your profile&#160;&#160;&#160;</span></span>\n".
         "<span class=\"mdc-notched-outline__trailing\"></span>\n".
         "</span>\n".
         "</label>\n".
         "</div>\n".
         "<div class=\"mdentryseparator\"></div></div>\n".
         "<div class=\"mdentryfieldbox\"><div class=\"mdentryfield\">\n".         
         "<button class=\"editprofile-button addcomment-button mdc-button mdc-button--raised\" type=\"submit\">\n".
         "<span class=\"mdc-button__label\">Save Profile</span></button></div></div>\n".
         "</form></div>\n".
         "<script>\n".
         "   mdc.ripple.MDCRipple.attachTo(document.querySelector(\'.editprofile-button\'));\n".
         "   mdc.textField.MDCTextField.attachTo(document.querySelector(\'.mdc-text-field\'));\n".
         "</script>\n";
   print "</body></html>";
}
# save editing form
else
{
   # update user profile
   open ( my $cfile, '>'.$userDir."/$userID.profile.xml" );
   print $cfile '<profile>'.
                $profile.
                '</profile>';
   close ($cfile);
   
   # get user activity glob
   my $maxuserlen = 6;
   my $maxuserglob = join ('', map { '?' } 1..$maxuserlen);

   # merge user bits into a single file
#   open ( my $cfile, '>'.$userRenderDir."/$userID.xml" );
#   print $cfile "<user>\n<type>Public Contributor</type>\n";      
#   print $cfile "</user>\n";
#   close ($cfile);
      
   system ("echo \'<user><type>Public Contributor</type>\' > $userRenderDir/$userID.xml; ".
           "cat $userDir/$userID.name.xml >> $userRenderDir/$userID.xml 2>/dev/null; ".
           "cat $userDir/$userID.profile.xml >> $userRenderDir/$userID.xml 2>/dev/null; ".
           "cat $userDir/$userID.$maxuserglob.xml >> $userRenderDir/$userID.xml; ".
           "echo \'</user>\' >> $userRenderDir/$userID.xml; ".
           "chmod a+w $userRenderDir/$userID.xml");

   # regenerate user page
   system ("$binDir/generate.pl --page users/$userID >/dev/null");

   # redirect to reload page
   print $cgi->redirect ("../users/$userID.html");
}
