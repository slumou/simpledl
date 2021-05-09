#!/usr/bin/perl
#
# Core admin tasks
# Hussein Suleman
# 26 October 2019

use CGI;

do './common.pl';

# get CGI variables
$cgi = new CGI;
# get the user login details
my $verify = $cgi->cookie ('verify');
my $loggedinuserID = $cgi->cookie ('userID');

# create login verification token
my $verifyCheck = '';
srand ($loggedinuserID+$verifySalt); 
for ( my $i=0; $i<20; $i++ )
{ $verifyCheck .= int(rand(10)); }
# check admin status of user
my $adminCheck = 0;
foreach my $admin (@administrators)
{
   if ($admin eq $loggedinuserID)
   { $adminCheck = 1; }
}

# perform verification check, delay and quit if no match
if (($verify ne $verifyCheck) || ($adminCheck == 0))
{
   sleep (3);
   
   open ( my $hfile, "adminheader.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   print $cgi->header;
   print $header;
   
   exit;
}

# display admin header
sub displayAdminHeader
{
   my ($cookies) = @_;

   open ( my $hfile, "adminheader.html");
   my @lines = <$hfile>;
   close ($hfile);
   my $header = join ('', @lines);
   $header =~ s/\<\/body\>.*\<\/html\>//s;
   
   if ((defined $cookies) && ($cookies ne ''))
   { print $cookies; }
   print $cgi->header;
   print $header;
   print "<div class=\"content\">\n".
         "<div class=\"manageroptions\"><b>Manager Options</b>: \n".
         "<div class=\"manageroption\"><form action=\"moderate.pl\"><input type=\"submit\" value=\"Moderate\"/> |</form></div>\n".
         "<div class=\"manageroption\"><form action=\"manage.pl\"><input type=\"submit\" value=\"Manage\"/> |</form></div>\n".
         "<div class=\"manageroption\"><form action=\"webimport.pl\">".
           "<input type=\"submit\" value=\"Import\"/> ".
           "<select name=\"option\">".
           "<option value=\"metadata\">metadata</option>".
           "<option value=\"users\">users</option>".
           "<option value=\"comments\">comments</option>".
           "<option value=\"uploads\">uploads</option>".
           "<option value=\"all\">all</option>".
           "</select> ".
           "force <input type=\"checkbox\" name=\"force\" value=\"1\"/>".
           "clean <input type=\"checkbox\" name=\"clean\" value=\"1\"/>".
         " |</form></div>\n".
         "<div class=\"manageroption\"><form action=\"webgenerate.pl\">".
           "<input type=\"submit\" value=\"Generate\"/> ".
           "<select name=\"option\">".
           "<option value=\"metadata\">metadata</option>".
           "<option value=\"website\">website pages</option>".
           "<option value=\"users\">users</option>".
           "<option value=\"thumbs\">thumbnails</option>".
           "<option value=\"composite\">composite thumbnails</option>".
           "<option value=\"all\">all</option>".
           "</select> ".
           "force <input type=\"checkbox\" name=\"force\" value=\"1\"/>".
         " |</form></div>\n".
         "<div class=\"manageroption\"><form action=\"webindex.pl\"><input type=\"submit\" value=\"Index\"/></form></div>\n".
         "</div>\n".
         "<hr/>\n";
}
