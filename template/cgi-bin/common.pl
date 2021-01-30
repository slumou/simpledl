#!/usr/bin/perl
#
# Link to config in main bin, and utility routines
# Hussein Suleman
# 8 December 2020

# yank in standard configuraton information
use FindBin;
$cwd = $FindBin::Bin;
do "$cwd/../../data/config/config.pl";

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
