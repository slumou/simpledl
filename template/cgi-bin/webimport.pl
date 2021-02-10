#!/usr/bin/perl
#
# Web interface to import script
# Hussein Suleman
# 26 October 2019

$|=1;

do './admin.pl';

displayAdminHeader ();

print "<h1>Import CSV files</h1><hr/><pre>\n";

my $options = '';
if ($cgi->param ("option") eq 'metadata')
{
   $options = ' --dir';
}
elsif ($cgi->param ("option") eq 'users')
{
   $options = ' --users';
}
elsif ($cgi->param ("option") eq 'comments')
{
   $options = ' --comments';
}
elsif ($cgi->param ("option") eq 'uploads')
{
   $options = ' --uploads';
}
elsif ($cgi->param ("option") eq 'all')
{
   $options = ' --all';
}

if ($cgi->param ("force") == 1)
{
   $options .= ' --force';
}

system ("cd \'$binDir\'; perl import.pl".$options);

print "</pre></body></html>";
