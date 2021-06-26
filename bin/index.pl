#!/usr/bin/perl

# Create all the indices needed for search and browse
# Hussein Suleman
# April 2019

$|=1;

use POSIX;
use XML::DOM::XPath;

binmode STDOUT, ":utf8";

use FindBin;
use lib "$FindBin::Bin";

do "$FindBin::Bin/../../data/config/config.pl";

do "$FindBin::Bin/stopwords.pl";

my $indexLocation = "$renderDir/indices";


sub index_dir
{
   my ($ifmap, $primary, $filepath, $other, $if, $ifb, $sort, $fmap, $titlemap, $fileid, $titlematch, $fileexclude, $browselocations) = @_;
   
   opendir (my $adir, $primary.'/'.$filepath);
   while (my $afile = readdir ($adir))
   {
      if ($afile !~ /^\.+$/)
      {
         if (-d $primary.'/'.$filepath.'/'.$afile)
         {
            ($fileid) = index_dir ($ifmap, $primary, $filepath.'/'.$afile, $other, $if, $ifb, $sort, $fmap, $titlemap, $fileid, $titlematch, $fileexclude, $browselocations);
         }
         elsif (($afile =~ /^[^\.]+\.xml$/) && (! defined $fileexclude->{$afile}) && (! defined $fileexclude->{$filepath.'/'.$afile}))
         {
            ($fileid) = index_file ($ifmap, $primary, substr ($filepath.'/'.$afile, 2), $other, $if, $ifb, $sort, $fmap, $titlemap, $fileid, $titlematch, $fileexclude, $browselocations);
         }
      }
   }
   closedir ($adir);
   
   ($fileid);
}

sub index_file
{
   my ($ifmap, $primary, $filename, $other, $if, $ifb, $sort, $fmap, $titlemap, $fileid, $titlematch, $fileexclude, $browselocations) = @_;

   # get primary item content
   open (my $afile, "<:utf8", $primary.'/'.$filename);
   my @lines = <$afile>;
   close ($afile);
   my $data = join ('', @lines);

#   print "$directory $primary $filename @$other\n";

   # add in additional content from related areas
   foreach my $other_entry (@$other)
   {
      if (-e "$other_entry/$filename")
      {
         open (my $afile, "<:utf8", "$other_entry/$filename");
         my @lines = <$afile>;
         close ($afile);
         $data .= join ('', @lines);
      }
   }
   
   # add in filename and path info
   if ($filename =~ /^(.*)\/([^\/]+\.xml)$/)
   {
      my @paths = split ('/', $1);
      my @fullpaths = map { '<subpath>'.join ('/', @paths[0..$_]).'</subpath>' } (0..$#paths);
      $data .= "<filename><path>$1</path><file>$2</file>".join ("", @fullpaths)."</filename>";
   }
   elsif ($filename =~ /^([^\/]+\.xml)$/)
   {
      $data .= "<filename><path></path><file>$1</file></filename>";
   }
   
   # encapsulate
   $data = "<fullrecord>$data</fullrecord>";

   # parse XML
   my $parser = new XML::DOM::Parser;
#   print ".";
   my $doc = $parser->parse ($data);

   foreach my $field ( keys %{$ifmap} )
   {
      my @locations = split (';', $ifmap->{$field});
      foreach my $location ( @locations )
      {
         my $data = '';
         my $weight = 1;
         # check for weight prefixed to field spec
         if ($location =~ /^weight=([0-9\.]+) (.*)$/)
         {
            $weight = $1;
            $location = $2;
         }
#      print $ifmap->{$field}."\n";
#      if ($field eq 'all')
#      {
#         foreach my $node ($doc->findnodes ("*//text()"))
#         { $data .= ' '.$node->toString };
#      }
#      else
#      {
#         print "indexing ... $field ... $ifmap->{$field}\n";
         foreach my $node ($doc->findnodes ($location))
         {
            if ($node->hasChildNodes) # to cater for matched elements
            {
               my $d = $node->getChildNodes->item(0)->toString; 
               $data .= ' '.$d;
               # eliminate leading spaces
               $d =~ s/^\s+//;
               foreach my $bfield (keys %{$browselocations->{$field}})
               {
                  index_browse_data ($bfield, $d, $ifb, $fileid);
               }
            }
            else # to cater for plain *//text() nodes
            {
               $data .= ' '.$node->toString;
            }
         }
#      }
#      print "$field $data $ifmap->{$field} \n";
         # eliminate leading spaces
         $data =~ s/^\s+//;
         index_search_data ($field, $data, $weight, $if, $fileid);
         if ((exists $sort->{$field}) && ($data ne ''))
         { index_sort_data ($field, $data, $sort, $fileid); }
      }   
   }
   
   my $title = 'No title';
   my @nodes = $doc->findnodes ($titlematch);
   if ($#nodes > -1)
   {
      if ($nodes[0]->hasChildNodes)
      { $title = $nodes[0]->getChildNodes->item(0)->toString; }
   }
   $titlemap->{$fileid} = $title;
   
   # if this is a metadata file, point to the index.xml instead
   if ($filename =~ /(.*)metadata.xml/)
   {
      $filename = $1.'index.xml';
   }
   
   $fmap->{$fileid} = $filename;
   $fileid++;
   
   ($fileid);
}

sub index_search_data
{
   my ($field, $data, $weight, $if, $fileid) = @_;
   
#   $data =~ s/\<[^\>]*\>/ /go;
   $data =~ s/&(nbsp|apos|quot|lt|gt);/ /go;
   $data =~ s/([\s\n\t\r'"@#\$%^&*\(\)_\-=\+\{\[\]\}\\\/;:,\<\>\.\?]|(\x{2013}|\x{2018}|\x{2019}|\x{201c}|\x{201d}|\x{2026}))+/ /go;
   $data = lc($data);
   
   my @words = split (' ', $data);
   foreach my $aword (@words)
   {
      if (! exists $stopwords{$aword})
      {
         if (! exists $if->{$field}->{$aword})
         {
            $if->{$field}->{$aword} = {};
         }
         if (! exists $if->{$field}->{$aword}->{$fileid})
         {
            $if->{$field}->{$aword}->{$fileid} = 0;
         }
         $if->{$field}->{$aword}->{$fileid} += $weight/($#words+1);
      }
   }
}

sub index_browse_data
{
   my ($field, $data, $ifb, $fileid) = @_;
   
   if (! exists $ifb->{$field}->{$data})
   {
      $ifb->{$field}->{$data} = {};
   }
   $ifb->{$field}->{$data}->{$fileid} = 1;
}


sub index_sort_data
{
   my ($field, $data, $sort, $fileid) = @_;
   
   if (! exists $sort->{$field}->{$data})
   {
      $sort->{$field}->{$data} = [ $fileid ];
   }
   else
   {
      push (@{$sort->{$field}->{$data}}, $fileid);
   }   
}


sub output_search_if
{
   my ($toplevel, $id, $if, $fmap, $titlemap) = @_;

   mkdir ("$indexLocation");
   mkdir ("$indexLocation/$toplevel");
   mkdir ("$indexLocation/$toplevel/search");
   mkdir ("$indexLocation/$toplevel/search/$id");
   
   foreach my $field (keys %$if)
   {
      mkdir ("$indexLocation/$toplevel/search/$id/$field");
      foreach my $aword (keys %{$if->{$field}})
      {
         my $bword = $aword;
         $bword =~ s/([^a-zA-Z0-9])/'_'.ord ($1).'_'/goe;
   
         open (my $ifile, ">:utf8", "$indexLocation/$toplevel/search/$id/$field/_$bword.xml");
         print $ifile "<index>\n";
         foreach my $fileid (keys %{$if->{$field}->{$aword}})
         {
            my $rounded = sprintf ("%.3f", $if->{$field}->{$aword}->{$fileid});
            if ($rounded eq '0.000')
            { $rounded = '0.001'; }
            my $filename = $fmap->{$fileid};
            my $title = $titlemap->{$fileid};
            print $ifile "<tf id=\"$fileid\" file=\"$filename\" title=\"$title\">$rounded</tf>\n";
         }
         print $ifile "</index>\n";
         close ($ifile);
      }
   }   
}

sub output_browse_if
{
   my ($toplevel, $id, $ifb, $fmap, $titlemap) = @_;

   mkdir ("$indexLocation");
   mkdir ("$indexLocation/$toplevel");
   mkdir ("$indexLocation/$toplevel/browse");
   mkdir ("$indexLocation/$toplevel/browse/$id");
   
   foreach my $field (keys %$ifb)
   {
      mkdir ("$indexLocation/$toplevel/browse/$id/$field");
      my $browse_no = 0;
      open (my $ifile, ">:utf8", "$indexLocation/$toplevel/browse/$id/$field/index.xml");
      print $ifile "<index>\n";
      foreach my $entry (sort keys %{$ifb->{$field}})
      {
         print $ifile "<entry id=\"$browse_no\">$entry</entry>\n";
   
         open (my $ifile2, ">:utf8", "$indexLocation/$toplevel/browse/$id/$field/$browse_no.xml");
         print $ifile2 "<index>\n";
         foreach my $fileid (keys %{$ifb->{$field}->{$entry}})
         {
            my $filename = $fmap->{$fileid};
            my $title = $titlemap->{$fileid};
            print $ifile2 "<bif id=\"$fileid\" file=\"$filename\" title=\"$title\"/>\n";
         }
         print $ifile2 "</index>\n";
         close ($ifile2);
         
         $browse_no++;
      }
      print $ifile "</index>\n";
      close ($ifile);
   }   
}

sub output_sort_if
{
   my ($toplevel, $sort, $fmap, $titlemap, $fileid) = @_;

   mkdir ("$indexLocation");
   mkdir ("$indexLocation/$toplevel");
   mkdir ("$indexLocation/$toplevel/sort");
   
   foreach my $field (keys %$sort)
   {
      if ($field eq 'relevance')
      { next; }
      mkdir ("$indexLocation/$toplevel/sort/$field");
      my %done = ();
      open (my $ifile, ">:utf8", "$indexLocation/$toplevel/sort/$field/index.xml");
      print $ifile "<index>\n";
      foreach my $entry (sort keys %{$sort->{$field}})
      {
         foreach my $id (@{$sort->{$field}->{$entry}})
         {
            my $filename = $fmap->{$id};
            my $title = $titlemap->{$id};
            print $ifile "<sif id=\"$id\" file=\"$filename\" title=\"$title\"/>\n";
            $done{$id} = 1;
         }   
      }
      for ( my $id=0; $id<$fileid; $id++ )
      {
         if (! exists $done{$id})
         {
            my $filename = $fmap->{$id};
            my $title = $titlemap->{$id};
            print $ifile "<sif id=\"$id\" file=\"$filename\" title=\"$title\"/>\n";
         }   
      }
      print $ifile "</index>\n";
      close ($ifile);
   }   
}

sub output_fulllist
{
   my ($toplevel, $id, $fmap, $titlemap, $fileid) = @_;

   mkdir ("$indexLocation");
   mkdir ("$indexLocation/$toplevel");
   mkdir ("$indexLocation/$toplevel/fulllist");
   
   open (my $ifile, ">:utf8", "$indexLocation/$toplevel/fulllist/index.xml");
   print $ifile "<index>\n";
   for ( my $f=0; $f<$fileid; $f++ )
   {
      my $filename = $fmap->{$f};
      my $title = $titlemap->{$f};
      print $ifile "<tf id=\"$f\" file=\"$filename\" title=\"$title\"/>\n";
   }
   print $ifile "</index>\n";
   close ($ifile);
}

sub delete_indices
{
   system ("rm -fR $indexLocation");
}

sub create_fulltexts
{
   my ($directory, $primary, $fulltext, $filepath)  = @_;
   
   opendir (my $adir, $primary.'/'.$filepath);
   while (my $afile = readdir ($adir))
   {
      if ($afile !~ /^\.+$/)
      {
         if (-d $primary.'/'.$filepath.'/'.$afile)
         {
            if (! -e $fulltext.'/'.$filepath.'/'.$afile)
            {
               mkdir ($fulltext.'/'.$filepath.'/'.$afile);               
            }
            create_fulltexts ($directory, $primary, $fulltext, $filepath.'/'.$afile);
         }
         elsif (($afile =~ /^[^\.]+\.xml$/) && 
                (! defined $file_exclude->{$afile})
                # 2 lines below to comment out to not check for existing extractions
                &&
                (! -e $fulltext.'/'.$filepath.'/'.$afile)
                )
         {         
            my $parser = new XML::DOM::Parser;
#print "FILE:".$directory.'/'.$primary.'/'.$filepath.'/'.$afile."\n";
            my $doc = $parser->parsefile ($primary.'/'.$filepath.'/'.$afile);
            
            my $fulltext_blob = '';
            foreach my $view ($doc->getElementsByTagName ('view'))
            {
               foreach my $viewfile ($view->getElementsByTagName ('file'))
               {
                  if ($viewfile->hasChildNodes)
                  {
                     my $fulltextfilename = $viewfile->getFirstChild->toString;
                     if (($fulltextfilename =~ /\.[pP][dD][fF]$/) && 
                         (-e "$directory/collection/$fulltextfilename"))
                     {
                        print "Extracting fulltext from $fulltextfilename\n";
                        open ( my $f, "pdftotext -enc ASCII7 \'$directory/collection/$fulltextfilename\' - |");
                        while (my $aline = <$f>)
                        {
                           $aline =~ s/[\&\<\>\'\"]/ /go;
                           $fulltext_blob .= $aline;
                        }
                        close ($f);
                     }
                  }
               }
            }
            $fulltext_blob =~ s/^\w+$//go;
            $fulltext_blob =~ s/[^a-zA-Z0-9]/ /go;
            if ($fulltext_blob ne '')
            {
               open ( my $f, ">".$fulltext.'/'.$filepath.'/'.$afile);
               print $f "<fulltext>".$fulltext_blob."</fulltext>";
               close ($f);
            }
         }
      }
   }
   closedir ($adir);   
}

sub main
{
   print "Updating extracted fulltexts\n";
   create_fulltexts ($renderDir, $metadataDir, $fulltextDir, '.');
   
#   print "Deleting old indices\n";
#   delete_indices ();

#   foreach my $toplevel ( "users" )
#   foreach my $toplevel ( "main" )
   foreach my $toplevel ( keys %{$indexers} )
   {
      print "Processing $toplevel\n";

      # create search and browse indices
      foreach my $index_id ( @{$indexers->{$toplevel}->{'field_index'}} )
      {
         my ($id , $name, $location) = @{$index_id};
         print "Creating search/browse index: [ID=$id, Name=$name, Location=$location]\n";
         my ($if, $ifb, $sort, $ifmap, $fmap, $titlemap, $browselocations, $fileid) = ({}, {}, {}, {}, {}, {}, {}, 0);
         foreach my $field ( keys %{$indexers->{$toplevel}->{'field_search'}})
         {
            $if->{$field} = {};
            $ifmap->{$field} = $indexers->{$toplevel}->{'field_search'}->{$field};
         }
# no need to add this because it is no longer implicit
#         $if->{'all'} = {};
#         $ifmap->{'all'} = 'all';
         foreach my $field ( @{$indexers->{$toplevel}->{'field_browse'}} )
         {
            $ifb->{$field->[0]} = {};
            for ( my $i=2; $i<=$#{$field}; $i++ )
            {
               if (! defined $browselocations->{$field->[$i]})
               {
                  $browselocations->{$field->[$i]} = {};
               }
               $browselocations->{$field->[$i]}->{$field->[0]}=1;
            }
         }
         foreach my $field ( @{$indexers->{$toplevel}->{'field_sort'}} )
         {
            $sort->{$field} = {};
         }
         my ($primary, @other) = split (',', $location);
         my $titlematch = $indexers->{$toplevel}->{'title_match'};
         ($fileid) = index_dir ($ifmap, $primary, ".", \@other, $if, $ifb, $sort, $fmap, $titlemap, $fileid, $titlematch, $indexers->{$toplevel}->{'file_exclude'}, $browselocations);
         output_search_if ($toplevel, $id, $if, $fmap, $titlemap);
         output_browse_if ($toplevel, $id, $ifb, $fmap, $titlemap);
         output_fulllist ($toplevel, $id, $fmap, $titlemap, $fileid);
         output_sort_if ($toplevel, $sort, $fmap, $titlemap, $fileid);
      }
   }
}

main;

