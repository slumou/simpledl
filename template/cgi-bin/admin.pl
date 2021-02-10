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
         "<b>Manager Options</b>: ".
         "<a href=\"moderate.pl\">Moderate</a> | ".
         "<a href=\"manage.pl\">Manage Files</a> | ".
         "<a href=\"webimport.pl\">Import CSVs</a> | ".
         "<a href=\"webgenerate.pl\">Generate Site</a> | ".
         "<a href=\"webindex.pl\">Create Index</a>\n".
         "<hr/>\n";
}
