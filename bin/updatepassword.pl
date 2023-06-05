#!/usr/bin/perl

# manually update a password
# Hussein Suleman
# 5 June 2023

use FindBin;
use lib "$FindBin::Bin";
do "$FindBin::Bin/../../data/config/config.pl";

# get user ID and password
print "SimpleDL Manual Password Update\n\n";
print "Enter the user ID to reset the password: ";
my $userID = <>;
chomp $userID;
print "Enter the new password: ";
my $userpassword = <>;
chomp $userpassword;

# update password details
my $passfilename = $userID.'.password.xml';
open ( my $passfile, '>'.$userDir.'/'.$passfilename);
my $encrypted = crypt ($userpassword, join ("", (".", "/", 0..9, "A".."Z", "a".."z")[rand 64, rand 64]));
print $passfile '<password>'.$encrypted.'</password>';
close ($passfile);
