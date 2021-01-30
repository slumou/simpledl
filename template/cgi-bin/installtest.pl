#!/usr/bin/perl

print "Content-type: text/plain\n\n";

print "Testing some basic features of installation\n\n";

# check ability to create a file
print "Checking file creation\n"; 
open (my $file, ">testfile.test");
print $file "12345";
close ($file);
if (-e 'testfile.test')
{ print "OK"; }
else
{ print "FAIL"; }
print "\n\n";

# check username of file
print "Checking username of process (using file creation)\n";
system ("ls -l testfile.test");
print "\n";

# file deletion
print "Checking file deletion\n";
unlink ("testfile.test");
if (! -e 'testfile.test')
{ print "OK"; }
else
{ print "FAIL"; }
print "\n\n";


