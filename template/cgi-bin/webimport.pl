#!/usr/bin/perl
#
# Web interface to import script
# Hussein Suleman
# 26 October 2019

$|=1;

do './admin.pl';

displayAdminHeader ();

print "<h1>Import CSV files</h1><hr/><pre>\n";

system ("cd \'$binDir\'; perl import.pl");

print "</pre></body></html>";
