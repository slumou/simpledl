# read in a CSV file
# Hussein Suleman
# June 2019

package CSV;
require Exporter;

use strict;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT    = qw(getCSV);

#use FindBin;
#my $cwd = $FindBin::Bin;

use Unicode::Normalize qw (NFD);
use utf8;

sub getCSV
{
   my ($filename) = @_;

   open (my $f, "<$filename");
   my @data = <$f>;
   close ($f);
   
   my @fields = CSVParse (join ("", @data));
   my $headings = shift (@fields);
   
   ($headings, \@fields);
}

sub CSVParse
{
   my ($s) = @_;

   my @lines = ();
   my $fields = [];
   my $buffer = '';
   my $outside = 1;
   
   my @chars = split ('', $s);
   my $i = 0;
   
   while ($i <= $#chars)
   {
      my $ch = $chars[$i];
      $i++;

      if (($ch eq ',') && ($outside == 1))
      {
         push (@$fields, $buffer);
         $buffer = '';
      }
      elsif (($ch eq '"') && ($outside == 1))
      {
         $outside = 0;
      }
      elsif (($ch eq '"') && ($outside == 0))
      {
         $outside = 1;
      }
      elsif ($ch eq '\\')
      {
         $ch = $chars[$i];
         $i++;
         $buffer .= $ch;
      }
      elsif (($ch eq "\n") && ($outside == 1))
      {
         if ($buffer ne '')
         { 
            push (@$fields, $buffer); 
            $buffer = '';
         }
         if ($#$fields > -1)
         { 
            push (@lines, $fields);
            $fields = []; 
         }
      }
      elsif ($ch ne "\r")
      {
         $buffer .= $ch;
      }
   }

   if ($buffer ne '')
   { push (@$fields, $buffer); }
   if ($#$fields > -1)
   { push (@lines, $fields); }
  
   @lines;
}

