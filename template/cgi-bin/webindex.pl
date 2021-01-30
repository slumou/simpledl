#!/usr/bin/perl
#
# Web interface to index for search/browse
# Hussein Suleman
# 26 October 2019

$|=1;

do './admin.pl';

displayAdminHeader ();

print "<h1>Create indices for search/browse</h1><hr/><pre>\n";

system ("cd \'$binDir\'; perl index.pl");

print "</pre></body></html>";
