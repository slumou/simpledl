#!/usr/bin/perl
#
# Web interface to import script
# Hussein Suleman
# 26 October 2019

$|=1;

do './admin.pl';

displayAdminHeader ();

print "<h1>Generate HTML files</h1><hr/><pre>\n";

my $options = '';
if ($cgi->param ("option") eq 'metadata')
{
   $options = ' --dir';
}
elsif ($cgi->param ("option") eq 'users')
{
   $options = ' --users';
}
elsif ($cgi->param ("option") eq 'thumbs')
{
   $options = ' --thumbs';
}
elsif ($cgi->param ("option") eq 'composite')
{
   $options = ' --composite';
}
elsif ($cgi->param ("option") eq 'website')
{
   $options = ' --website';
}
elsif ($cgi->param ("option") eq 'all')
{
   $options = ' --all';
}

if ($cgi->param ("force") == 1)
{
   $options .= ' --force';
}

system ("cd \'$binDir\'; perl generate.pl".$options);

print "</pre></body></html>";
