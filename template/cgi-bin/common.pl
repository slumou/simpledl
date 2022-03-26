#!/usr/bin/perl
#
# Link to config in main bin, and utility routines
# Hussein Suleman
# 8 December 2020

# yank in standard configuraton information
use FindBin;
$cwd = $FindBin::Bin;
do "$cwd/../../data/config/config.pl";

use MIME::Lite;

# get new unique ID
sub getID
{
   my ($domain) = @_;

   my $counter = 1;
   if (-e $counterDir.'/'.$domain.".counter")
   {
      open (my $cfile, $counterDir.'/'.$domain.".counter");
      $counter = <$cfile>;
      chomp $counter;
      close ($cfile);
   }
   $counter++;
   open (my $cfile, '>'.$counterDir.'/'.$domain.".counter");
   print $cfile $counter."\n";
   close ($cfile);
   $counter;
}

# send email
sub sendEmail
{
   my ($useremail, $subject, $message) = @_;
   
   $msg = MIME::Lite->new(
      From     => $SMTPFrom,
      To       => $useremail,
      Subject  => $subject,
      Data     => $message
   );

   my $x = $msg->send ("smtp", $SMTPServer);
}

# send admins email
sub sendAdminEmail 
{
   my ($subject, $message) = @_;

   foreach my $adminID (@administrators)
   {
      if (-e $userDir.'/'.$adminID.".email.xml")
      {
         my $email = '';
         open (my $efile, $userDir.'/'.$adminID.".email.xml");
         $email = <$efile>;
         chomp $email;
         close ($efile);
       
         if ($email =~ /\<email\>(.*)\<\/email\>/)
         {
            sendEmail ($1, $subject, $message);
         }
      }
   }
}
