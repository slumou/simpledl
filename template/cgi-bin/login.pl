#!/usr/bin/perl
#
# Login or add to moderation queue
# Hussein Suleman
# 23 October 2019

use CGI;
use POSIX qw(strftime);
use IO::File;
use IO::Handle;

do './common.pl';

# get CGI variables
my $cgi = new CGI;                       
my $username = $cgi->param ('username');
my $useremail = $cgi->param ('useremail');
my $googlecookie = $cgi->param ('googlecookie');

# remember to validate against google web service!

# check user directory for matching user
opendir (my $sdir, $userDir);
my @files = readdir ($sdir);
closedir ($sdir);
@files = grep { /\.email\.xml$/ } @files;
my $loggedinuserID = 0;
my $loggedinusername = '';
my $moderation = 0;
my $administrator = 0;
my $verify = '';
foreach my $afile (@files)
{
   open ( my $userfile, $userDir.'/'.$afile);
   my @datalines = <$userfile>;
   close ($userfile);
   my $data = join ('', @datalines);
   
   if ($data =~ /\<email\>(.*)\<\/email\>/)
   {
      my $e = $1;
      if ($e eq $useremail)
      {
         $loggedinuserID = substr ($afile, 0, -10);
#         print "$loggedinuserID MATCH\n";

         # update number of items awaiting moderation
         opendir (my $mdir, $moderationDir);
         my @files = readdir ($mdir);
         closedir ($mdir);
         @files = grep { /[0-9]/ } @files;
         $moderation = $#files + 1;
         
         # update admin status
         foreach my $admin (@administrators)
         {
            if ($admin eq $loggedinuserID)
            { 
               $administrator = 1; 
            }
         }
         
         # create login verification token
         srand ($loggedinuserID+$verifySalt); 
         for ( my $i=0; $i<20; $i++ )
         { $verify .= int(rand(10)); }
      }
   }
}

if ($loggedinuserID ne '0')
{
   print "Set-Cookie: userID=$loggedinuserID; Path=/\n".
         "Set-Cookie: username=$username; Path=/\n".
         "Set-Cookie: moderation=$moderation; Path=/\n".
         "Set-Cookie: admin=$administrator; Path=/\n".
         "Set-Cookie: verify=$verify; Path=/\n".
         "Content-type: text/html\n\n".
         "<html><body><script>\n".
         "window.opener.location.reload (false);\n".
         "window.close ();\n".
         "</script></body><html>";
}
else
{
   open ( my $hfile, "popupheader.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   $header =~ s/\<\/body\>.*\<\/html\>//s;
   
   print $cgi->header;
   print $header;

   print "<div class=\"content\">\n".
         "<h1>Login</h1>\n".
         "<p>Step 3: It seems that you are not registered with this account.  Please fill out this form to request an account</p>\n".
         "<form name=\"adduserform\" class=\"adduserformclass\" method=\"post\" action=\"add.pl\">\n".
         "<p><b>User name:</b> $username</p>\n".
         "<input type=\"hidden\" name=\"user\" value=\"$username\"/>\n".
         "<p><b>Login email:</b> $useremail\n".
         "<br/><small>(If this is not the account you use, <a href=\"#\" onclick=\"window.history.back(); return false\">Click here to go back</a> and change it)</small></p>\n".
         "<input type=\"hidden\" name=\"email\" value=\"$useremail\"/>\n".
         "<div class=\"mdc-text-field mdc-text-field--textarea adduserboxclass\">\n".
         "<textarea id=\"motivationbox\" name=\"motivation\" class=\"mdc-text-field__input\" rows=\"7\" cols=\"40\">Position: \nAffilitation: \nMotivation: \n</textarea>\n".
         "<div class=\"mdc-notched-outline\">\n".
         "<div class=\"mdc-notched-outline__leading\"></div>\n".
         "<div class=\"mdc-notched-outline__notch\"><label for=\"textarea\" class=\"mdc-floating-label\">Enter a short motivation for an account</label></div>\n".
         "<div class=\"mdc-notched-outline__trailing\"></div>\n".
         "</div>\n".
         "</div>\n".
         "<button class=\"adduser-button mdc-button mdc-button--raised\" type=\"submit\">\n".
         "<span class=\"mdc-button__label\">Submit Request</span></button>\n".
         "</form></div>\n".
         "<script>\n".
         "   mdc.ripple.MDCRipple.attachTo(document.querySelector(\'.adduser-button\'));\n".
         "   mdc.textField.MDCTextField.attachTo(document.querySelector(\'.adduserboxclass\'));\n".
         "</script>\n".
         "</div></body></html>\n";
}
