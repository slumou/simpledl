#!/usr/bin/perl
#
# Dynamic Web archive file extraction on demand
# Hussein Suleman
# sometime in 2003
#

# remember that mime is always called after admin, which always calls common.pl!

# get mapping of mime types to filename extensions
open (FILE, $dataDir.'/mime.types');
my @mimelines = <FILE>;
close (FILE);

# create mime type mapping for future lookups
my %mimemap = ();
foreach my $mimeline (@mimelines)
{
   chomp $mimeline;
   if (($mimeline ne '') && (substr ($mimeline, 0, 1) ne '#'))
   {
      my @fields = split (/\s+/, $mimeline);
      for (my $i=1; $i<=$#fields; $i++ )
      {
         $mimemap{lc($fields[$i])} = $fields[0];
      }
   }
}

# return mime type for a given filename
sub mime
{
   my ($filename) = @_;
   
   my $ext = '';
   if ($filename =~ /(.*)\.([a-zA-Z]+)$/)
   {
      $ext = lc($2);
   }
   if (exists $mimemap{$ext})
   { return $mimemap{$ext}; }
   return 'text/plain';
}

