#!/usr/bin/perl
#
# Manage datasets
# Hussein Suleman
# 26 October 2019

use File::Copy;
use POSIX qw(strftime);

do './admin.pl';
do './mime.pl';

# get CGI variables
my $action = $cgi->param ('action');
my $dataset = $cgi->param ('dataset');
my $path = $cgi->param ('path');
my $folder = $cgi->param ('folder');
my $uploadfile = $cgi->upload ('uploadfile');
my $uploadfilename = $cgi->param('uploadfile');

my $autoexpand = 2;
my $filelimit = 1073741824; # 1 gigabyte

# possible actions for this script
sub main 
{
   if ($action eq '')
   { $action = 'listdata'; }
   if ($dataset eq '')
   { $dataset = $managed->[0]->[0]; }
   if ($path eq '')
   { $path = '.'; }

   if ($action eq 'listdata')
   { 
      listDirectories ($dataset, $path); 
   }
   elsif (($action eq 'createfolder') && ($folder ne '') && ($path ne ''))
   {
      createFolder ($path, $folder);
      listDirectories ($dataset, '.');
   }
   elsif (($action eq 'downloadfile') && ($path ne ''))
   {
      downloadFile ($path);
   }
   elsif (($action eq 'deletefile') && ($path ne ''))
   {
      deleteFile ($path);
      listDirectories ($dataset, '.');
   }
   elsif (($action eq 'uploadfile') && ($path ne '') && ($uploadfilename ne ''))
   {
      uploadFile ($path, $uploadfile, $uploadfilename);
      listDirectories ($dataset, '.');
   }
}

# create a folder
sub createFolder
{
   my ($path, $folder) = @_;
   
   mkdir ($path.'/'.$folder);
   system ("chmod a+rx \"$path/$folder\"");
}

# download a file
sub downloadFile
{
   my ($path) = @_;
   
   my $filename = $path;
   if ($filename =~ /\/([^\/]+)$/)
   {
      $filename = $1;
   }
   
#   $path = '../../'.$path;
   if (-e $path)
   {
      print "Content-type: ".mime ($path)."\n".
            "Content-Disposition: attachment; filename=$filename;\n".
            "Cache-control: max-age=300, public\n\n";
      open (FILE, $path);
      my @contents = <FILE>;
      print @contents;
      close (FILE);
   }
}

# delete a file or folder
sub deleteFile
{
   my ($path) = @_;
   
#   $path = '../../'.$path;
#   if (-d $path)
#   { 
#      rmdir ($path); 
      # instead of removing directory or a file, move it out of this space

      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime ();
      my $stamp = sprintf ("%04d-%02d-%02d.%d", $year+1900, $mon+1, $mday, $$);

      mkdir ("$dbDir/deletedcollection");
      mkdir ("$dbDir/deletedcollection/$stamp");
      move ($path, "$dbDir/deletedcollection/$stamp/");
#   }
#   else
#   { unlink ($path); }
}

# store a file with a filesize limit
sub storeFile
{
   my ($uploadfile, $filename) = @_;

   my $buffer;
   my $totalbytes = 0;
   open ( my $outfile, ">$filename");
   while ( my $bytesread = $uploadfile->handle->read ($buffer, 1024) ) 
   {
      print $outfile $buffer;
      $totalbytes += $bytesread;
      if ($totalbytes > $filelimit)
      {
         close ($outfile);
         unlink ($filename);
         return;
      }
   }
   close ($outfile);
}

# upload a file or zip file
sub uploadFile
{
   my ($path, $uploadfile, $uploadfilename) = @_;
   
   if ($uploadfilename =~ /\.[zZ][iI][pP]$/)
   {
      my $tempFile = '/tmp/'.$$.$uploadfilename;
      storeFile ($uploadfile, $tempFile);      
      system ("cd \"$path\"; $unzip -o \"$tempFile\" -x \'__MACOSX*\' -x \'*.DS_Store\' ".'>/dev/null 2>&1');
      system ("cd \"$path\"; chmod -R a+r *; find . -type d -exec chmod 755 {} +");
#      system ("cd \"../../$path\"; $unzip -o \"$tempFile\" -x \'__MACOSX*\' -x \'*.DS_Store\' ".'>/dev/null 2>&1');
#      system ("cd \"../../$path\"; chmod -R a+r *");
      unlink ($tempFile);
   }
   else
   {
      storeFile ($uploadfile, $path.'/'.$uploadfilename);
      system ("chmod a+r \"$path/$uploadfilename\"");
#      storeFile ($uploadfile, '../../'.$path.'/'.$uploadfilename);
   }   
}

# display the list of items to be managed
sub listDirectories
{
   my ($dataset, $path) = @_;
   
   displayAdminHeader ();

   print "<h1>Manage Datasets</h1><hr/>\n";

   print "<b>Datasets:</b> ";
   my $datasetpath = '';
   foreach my $dset (@$managed)
   {
      if ($dset->[0] eq $dataset)
      {
         print "[<b>".$dset->[0]."</b>] ";
         $datasetpath = $dset->[1];
      }
      else
      {
         print "[<a href=\"\" onClick=\"document.manageform.path.value=\'\'; document.manageform.dataset.value=\'$dset->[0]\'; document.manageform.submit(); return false\">".$dset->[0]."</a>] ";
      }
   }
   print "<br/><b>Options</b>: Create [F]older, [D]elete file/folder, [U]pload file or ZIP<br/>";
   
   print "<hr/>";

   print "<form name=\"manageform\" class=\"manageformclass\" method=\"post\" enctype=\"multipart/form-data\" action=\"manage.pl\">".
         "<input type=\"hidden\" name=\"action\" value=\"listdata\"/>".
         "<input type=\"hidden\" name=\"dataset\" value=\"$dataset\"/>".
         "<input type=\"hidden\" name=\"path\" value=\"$path\"/>".
         "<input type=\"hidden\" name=\"folder\" value=\"\"/>".
         "Select a file to attach (for uploads): <input type=\"file\" id=\"uploadfile\" name=\"uploadfile\" onChange=\"updateUploads()\"/>".
         "</form>";

   print "<hr/>";
   
   processDir ($datasetpath, '', $path, '');
}

sub processDir
{
   my ($datasetpath, $offset, $path, $level) = @_;
   
   my $levelup = '...';
    
   if (! -d $datasetpath.$offset.'/'.$path)
   {
      my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) 
       = stat($datasetpath.$offset.'/'.$path);
      my $ltime = strftime ('%d %b %Y %H:%M:%S', localtime ($mtime));
#      print "[ &#160;] $level <a href=\"\" onClick=\"return downloadFile (\'$datasetpath\', \'$offset/$path\')\">$path</a> [$size bytes, $ltime]";
      print "[ &#160;] $level <a href=\"?action=downloadfile&path=$datasetpath$offset/$path\">$path</a> [$size bytes, $ltime]";
      print "&#160;&#160;";
      print " [<a href=\"\" onClick=\"return deleteFile (\'$datasetpath\', \'$offset/$path\')\">d</a>]";
      print "<br/>";
   }
   else
   {
      # get child files/directories
      opendir (my $dir, $datasetpath.$offset.'/'.$path);
      my @files = readdir ($dir);
      closedir ($dir);
      @files = grep { !/^\./ } @files;

      # auto-expand a specified number of levels
      my $defaultDisplay = "none";
      my $defaultIcon = '+';
      if ((length ($level) / length ($levelup)) < $autoexpand) 
      { 
         $defaultDisplay = "block"; 
         $defaultIcon = ' -'; 
      }
      
      # expansion buttons
      my $pathName = $path;
      if ($pathName eq '.') { $pathName = 'ROOT'; }
      my $pathNode = pathNode($datasetpath.$offset.'/'.$path);
      if ($#files == -1)
      {
         print "[ &#160;]";
      }   
      else 
      { 
         print "[<a id=\"$pathNode!a\" href=\"\" onclick=\"toggleExpand (\'$pathNode\'); return false\">$defaultIcon</a>]";
      }   
      print " $level $pathName"."/&#160;&#160;";

      # action links
      print " [<a href=\"\" onClick=\"return createFolder (\'$datasetpath$offset/$path\')\">f</a>]";
      if ($path ne '.')
#      if (($path ne '.') && ($#files == -1))
      { print " [<a href=\"\" onClick=\"return deleteFile (\'$datasetpath\', \'$offset/$path\')\">d</a>]"; }
      print "<span class=\"uclass\" style=\"display: none\"> ".
            "[<a href=\"\" onClick=\"return uploadFile (\'$datasetpath$offset/$path\')\">u</a>]</span>";
      print "<br/>";

      # process child files/directories
      print "<div id=\"$pathNode\" style=\"display: $defaultDisplay\">";
      foreach my $afile (@files)
      {
         processDir ($datasetpath, $offset.'/'.$path, $afile, $level.$levelup);
      }
      print "</div>";
   }
}

sub pathNode
{
   @_[0] =~ s/\//_/go;
   'NODE'.@_[0];
}

main;
