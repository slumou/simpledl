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

use Text::CSV;

sub getCSV
{
   my ($filename) = @_;
   
   # use external module instead of pureperl version below
   my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                           or die "Cannot use CSV: ".Text::CSV->error_diag ();

   my $fields = [];
   open ( my $fh, "<:encoding(utf8)", $filename );
   while ( my $row = $csv->getline( $fh ) ) {
      push (@{$fields}, $row);
   }
   $csv->eof;
   close ($fh);

#   my $fields = csv ( in=>$filename, encoding=>'UTF-8' );
   my $headings = shift @{$fields};
   ($headings, $fields);

#  quick interface to Text::CSV in later versions
#   open (my $f, "<:utf8", "$filename");
#   my @data = <$f>;
#   close ($f);
   
#   my @fields = CSVParse (join ("", @data));
#   my $headings = shift (@fields);
#   
#   ($headings, \@fields);
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

