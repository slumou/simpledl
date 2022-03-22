#!/usr/bin/perl
#
# Login or add to moderation queue
# Hussein Suleman
# 23 October 2019

use CGI;
use POSIX qw(strftime);
use IO::File;
use IO::Handle;
use MIME::Lite;
use URI::Escape;

do './common.pl';

# get CGI variables
my $cgi = new CGI;                       
my $userpassword = $cgi->param ('userpassword');
my $useremail = $cgi->param ('useremail');
my $username = $cgi->param ('username');
my $userID = $cgi->param ('userID');
my $usermotivation = $cgi->param ('usermotivation');
my $back = $cgi->param ('back');
my $action = $cgi->param ('action');
my $token = $cgi->param ('token');

# process functions of login script
if ($action eq 'newuser')
{
   newUser ($cgi, $useremail, $username, $usermotivation);
}
elsif ($action eq 'resetpassword')
{
   if ((! defined $userID) || (validToken ($userID, $token) == 0))
   {
      printError ($cgi, 'Invalid ID or token');
   }
   else
   { 
      resetPassword ($cgi, $userID, $userpassword, $token);
   }
}
elsif ($action eq 'forgotpassword')
{
   my $userID = getUserID ($useremail);
   if (defined $userID)
   { 
      forgotPassword ($cgi, $userID, $useremail);
   }
   else
   { printError ($cgi, 'Invalid email'); }
}
elsif ($action eq 'login')
{
   my $userID = getUserID ($useremail);
   if ((defined $userID) && (checkPassword ($userID, $userpassword) == 1))
   { printSuccess ($userID, $back); }
   else
   { printError ($cgi, 'Invalid email or password'); }
}
else
{
   printError ($cgi, 'Unknown error'); 
}

#
# various routines for different options
#

sub getUserID
{
   my ($useremail) = @_;
   
   # check user directory for matching user
   opendir (my $sdir, $userDir);
   my @files = readdir ($sdir);
   closedir ($sdir);
   @files = grep { /\.email\.xml$/ } @files;

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
            # get and check password
            if ($afile =~ /([0-9]+)\.email\.xml$/)
            {
               return $1;
            }
         }
      }
   }
   undef;
}               
            
sub checkPassword
{
   my ($userID, $userpassword) = @_;

   my $pafile = $userID.'.password.xml';
   open ( my $passfile, $userDir.'/'.$pafile);
   my @datalines = <$passfile>;
   close ($passfile);
   my $data = join ('', @datalines);
   if ($data =~ /\<password\>(.*)\<\/password\>/)
   {
      if ($1 eq crypt ($userpassword, $1))
      {
         return 1;
      }
   }
   0;
}         
         
sub printSuccess
{
   my ($userID, $back) = @_;
         
   # update admin status
   my $administrator = 0;
   foreach my $admin (@administrators)
   {
      if ($admin eq $userID)
      { 
         $administrator = 1; 
      }
   }
                     
   # create login verification token
   my $verify = '';
   srand ($userID+$verifySalt); 
   for ( my $i=0; $i<20; $i++ )
   { $verify .= int(rand(10)); }
   
   # get user name
   my $username = '';
   my $nafile = $userID.'.name.xml';
   open ( my $namefile, $userDir.'/'.$nafile);
   my @datalines = <$namefile>;
   close ($namefile);
   my $data = join ('', @datalines);
   if ($data =~ /\<name\>(.*)\<\/name\>/)
   {
      $username = $1;
   }

   # create cookies and go back where we came from
   print "Set-Cookie: userID=$userID; Path=/\n".
         "Set-Cookie: username=$username; Path=/\n".
         "Set-Cookie: admin=$administrator; Path=/\n".
         "Set-Cookie: verify=$verify; Path=/\n".
         "Content-type: text/html\n\n".
         "<html><head>".
         "<meta http-equiv=\"refresh\" content=\"0;url=$back\" />".
         "</head></html>";
}

sub printError
{
   my ($cgi, $message) = @_;
   
   sleep (3);

   open ( my $hfile, "header.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   $header =~ s/\<\/body\>.*\<\/html\>//s;
      
   print $cgi->header;
   print $header;
      
   print "<p>&#160;&#160;$message</p></div></body></html>\n";
}

sub forgotPassword
{
   my ($cgi, $userID, $useremail) = @_;

   # create a random token
   my $token = '';
   srand (); 
   for ( my $i=0; $i<20; $i++ )
   { $token .= int(rand(10)); }
   
   # save token
   my $tokenfilename = $userID.'.token.txt';
   open ( my $tokenfile, '>'.$userDir.'/'.$tokenfilename);
   print $tokenfile $token;
   close ($tokenfile);
   
   # send email
   my $url = $ENV{REQUEST_SCHEME}.'://'.$ENV{SERVER_NAME}.':'.$ENV{SERVER_PORT}.$ENV{SCRIPT_NAME};
   $url .= '?action=resetpassword&userID='.$userID.'&token='.$token;
   sendEmail ($useremail, 'Password change confirmation',
              "Please click on this link or open it in a new browser in order to continue with changing your password.\n\n$url");
   
   # display confirmation
   confirmationMessage ($cgi);
}

# write out confirmation message after sending an email link
sub confirmationMessage
{
   my ($cgi) = @_;
   
   open ( my $hfile, "header.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   $header =~ s/\<\/body\>.*\<\/html\>//s;
      
   print $cgi->header;
   print $header;
   
   print "<p>&#160;&#160;Please check your email for a confirmation link to continue.</p><p>You may need to check your spam folder.</p></div></body></html>\n";
}

# check that the token has not been tampered with
sub validToken
{
   my ($userID, $token) = @_;
   
   my $tokenfilename = $userID.'.token.txt';

   # create initial token
   my $realtoken = '';
   srand (); 
   for ( my $i=0; $i<20; $i++ )
   { $realtoken .= int(rand(10)); }

   # delete token filename if outdated (more than 30 min)
   if ((time - (stat($userDir.'/'.$tokenfilename))[9]) > 30*60)
   {
      unlink ($userDir.'/'.$tokenfilename);
   }
   else
   # get saved token
   {
      open ( my $tokenfile, $userDir.'/'.$tokenfilename);
      $realtoken = <$tokenfile>;
      close ($tokenfile);
      chomp $realtoken;
   }   
   
   # compare and return outcome
   if ($token eq $realtoken)
   { return 1; }
   else
   { return 0; }
}

sub resetPassword 
{
   my ($cgi, $userID, $userpassword, $token) = @_;

   # create form on first pass
   if ($userpassword eq '')
   {
      open ( my $hfile, "header.html");
      my @lines = <$hfile>;
      close ($hfile);
      my $header = join ('', @lines);
      $header =~ s/\<\/body\>.*\<\/html\>//s;
      
      print $cgi->header;
      print $header;
   
      print "<div class=\"content\">\n".
            "<h1>Change Password</h1>\n".
            "<form name=\"loginform\" class=\"loginformclass\" method=\"post\" action=\"#\" onSubmit=\"return validateLoginForm ()\">\n".
            "<input type=\"hidden\" name=\"userID\" value=\"$userID\"/>\n".
            
            "<div class=\"mdentryfieldbox\"><div class=\"mdentryfield\">\n".
            "<label class=\"mdc-text-field mdc-text-field--filled mdc-text-field--label-floating mdentryfieldwidth userpasswordboxclass\">\n".
            "<span class=\"mdc-text-field__ripple\"></span>\n".
            "<input class=\"mdc-text-field__input\" id=\"userpasswordbox\" name=\"userpassword\" type=\"password\" size=\"60\" aria-labelledby=\"userpasswordboxs\"/>\n".
            "<span class=\"mdc-floating-label mdc-floating-label--float-above\" id=\"userpasswordboxs\">Enter your password</span>\n".
            "<span class=\"mdc-line-ripple\"></span>\n".
            "</label>\n".
            "</div>\n".
            "<div class=\"mdentryseparator\"></div></div>\n".

            "<input type=\"hidden\" name=\"token\" value=\"$token\"/>\n".
            "<input type=\"hidden\" name=\"action\" value=\"resetpassword\"/>\n".

            "<div class=\"mdentryfieldbox\"><div class=\"mdentryfield\">\n".
            "<button id=\"loginbutton\" class=\"addcomment-button mdc-button mdc-button--raised\" type=\"submit\">\n".
            "<span class=\"mdc-button__label\">Update</span></button></div><div class=\"mdentryseparator\"></div></div>\n".

            "</form>\n".

            "<script>\n".
            "   mdc.textField.MDCTextField.attachTo(document.querySelector('.userpasswordboxclass'));\n".
            "   mdc.ripple.MDCRipple.attachTo(document.querySelector('.addcomment-button'));\n".
            "</script>\n";

      print "</div></body></html>\n";
   }
   else
   # process form contents and update password
   {
      # save token
      my $passfilename = $userID.'.password.xml';
      open ( my $passfile, '>'.$userDir.'/'.$passfilename);
      print $passfile '<password>'.
            crypt ($userpassword, join ("", (".", "/", 0..9, "A".."Z", "a".."z")[rand 64, rand 64])).
#            $userpassword.
            '</password>';
      close ($passfile);
      
      # go back to login page
      print "Set-Cookie: userID=; Path=/\n".
            "Set-Cookie: username=; Path=/\n".
            "Set-Cookie: admin=0; Path=/\n".
            "Set-Cookie: verify=0; Path=/\n".
            "Content-type: text/html\n\n".
            "<html><head>".
            "<meta http-equiv=\"refresh\" content=\"0;url=/\" />".
            "</head></html>";
   }      
}

sub newUser 
{
   my ($cgi, $useremail, $username, $usermotivation) = @_;
   
   # send email
   my $url = $ENV{REQUEST_SCHEME}.'://'.$ENV{SERVER_NAME}.':'.$ENV{SERVER_PORT}.$ENV{SCRIPT_NAME};
   $url =~ s/login\.pl$/add\.pl/;
   $url .= '?user='.uri_escape ($username).'&email='.uri_escape ($useremail).'&motivation='.uri_escape ($usermotivation);
   sendEmail ($useremail, 'New user application confirmation',
              "Please click on this link or open it in a new browser in order to submit the new user application.\n\n$url");
   
   # display confirmation
   confirmationMessage ($cgi);
}