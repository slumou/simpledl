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
my @optionlist = ();
if ($cgi->param ("option") eq 'metadata')
{
   push (@optionlist, '--dir');
}
elsif ($cgi->param ("option") eq 'users')
{
   push (@optionlist, '--users');
}
elsif ($cgi->param ("option") eq 'comments')
{
   push (@optionlist, '--comments');
}
elsif ($cgi->param ("option") eq 'uploads')
{
   push (@optionlist, '--uploads');
}
elsif ($cgi->param ("option") eq 'all')
{
   push (@optionlist, '--all');
}

if ($cgi->param ("force") == 1)
{
   push (@optionlist, '--force');
}
if ($cgi->param ("clean") == 1)
{
   push (@optionlist, '--clean');
}

$options = join (' ', @optionlist);
#print $options;

#@ARGV = @optionlist;
#unshift (@INC, $binDir); 
#print "$binDir/import.pl";
#do "$binDir/import.pl";

system ("cd \'$binDir\'; perl import.pl ".$options);

print "</pre></body></html>";
