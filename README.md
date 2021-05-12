# Simple DL

This is an experimental toolkit to create simple digital libraries, where the goal is
ease of preservation, ease of rescue and ease of development.

The toolkit manages and generates a self-contained Web experience around a
collection of digital objects and their associated metadata.  

Generating a site is a 3-step process: import data/configuration from sources; generate
HTML viewable version; and create index for search/browse.

## Major features

* metadata in ICA-AtoM or Dublin Core, created using spreadsheets (in CSV
format)
* no DBMS and minimal use of Web applications
* sites can be generated and then served locally (e.g., for mobile devices
not connected to the Internet)
* customisable using standard CSS and XSLT
* users can be extracted from metadata or added explicitly
* user submission of items
* comments on items
* moderation of submitted items/comments/user registrations
* Google authentication
* in-browser faceted search (search still with offline copies)
* online admin interface
* composite zip file viewer

## How to install on Ubuntu Linux

* install Apache HTTPD server and suexec-custom set up so suexec works in
  home directories
* dependencies: libxslt/xsltproc, imagemagick, unzip
* in the user's home directory, create "simpledl" and "public_html" directories
* change to the simpledl directory and run "git clone https://github.com/slumou/simpledl.git" .
* copy the sample data and db directories into the home directory
* edit data/users/1.email.xml to contain your Google account email
* run "simpledl/bin/import.pl" to import data/config
* run "simpledl/bin/generate.pl --all" to generate the site
* run "simpledl/bin/index.pl" to index the metadata
* configure your Web server to point to the public_html directory and
execute cgi scripts in the public_html/cgi-bin directory
* visit "http://yoursite/cgi-bin/admin.pl" and log in.


## How to configure the software

All configuration information is in the data directory, and this gets copies
across to public_html and/or used in generating the site.

* config/config.pl has the major configuration variables, including which
  fields get indexed for search/browse.
* website/styles/transform.xsl converts metadata and website files from
XML->HTML, so fundamental layout can be changed here
* website/styles/style.css is the global CSS file

Hussein Suleman
30 January 2021
 
