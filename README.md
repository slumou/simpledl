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

These instructions are to install Simple DL on a standard Ubuntu Linux variant, but they should easily be adaptable to other OSes as well.

### Step 1: Getting the sample archive and code for offline access

1. Create a new Linux user account.  In this example the account is called *docs*.

```
sudo adduser docsjournalctl -xe
```

2. Log in as the docs users.  In the user's home directory, create a directory named *simpledl* and change into this directory.

```
mkdir simpledl
cd simpledl
```

3. Obtain the source files and sample repository from github by cloning the repository into the simpledl directory.  Do not forget the period at the end!

```
git clone https://github.com/slumou/simpledl.git .
```

4. Uncompress the *sampledata*, *sampledb* and *samplepublic_html* archive files into the home directory.  You should then have *simpledl*, *public_html*, *data* and *db* in the home directory.

```
cd ..
gzip -cd simpledl/sampledata.tgz | tar -xf -
gzip -cd simpledl/sampledb.tgz | tar -xf -
gzip -cd simpledl/samplepublic_html.tgz | tar -xf -
```

5. Test the repository by opening a browser window and visiting the page:

```
file:///home/docs/public_html/index.html
```
-----

### Step 2: Setting up your Web server for online access

1. Either register a DNS name for your server or use a hosts entry to mimic this for a development machine.  Assuming the server's DNS name is docs.simpledl.net, you can set this in the */etc/hosts* file by editing the first line as follows.

```
127.0.0.1       localhost docs.simpledl.net
```

2. Install the Apache HTTPD Web server and suexec-custom set up so suexec works in home directories.  Suexec is a secure wrapper that Apache uses to execute applications as the user that owns the script, and suexec-custom is a variation that allows you configure suexec without recompiling the Web server.

```
sudo apt install apache2 apache2-suexec-custom
```

Configure suexec-custom by specifying the root for scripts for the server.  You can use */home* to keep all files in the home directory if this is not a widely-used production server.  If it is, it may be better to use */var/www* and then those selected users who are allowed to use Web applications can have directories within this.

*Contents of /etc/apache2/suexec/www-data*

    /home
    public_html/cgi-bin

Create a site configuration for the Web server.

*Contents of /etc/apache2/sites-available/docs.conf*

    <VirtualHost *:80>
    ServerName docs.simpledl.net
    DocumentRoot /home/docs/public_html
    SuexecUserGroup docs docs
    ScriptAlias /cgi-bin/ "/home/docs/public_html/cgi-bin/"
    CustomLog /home/docs/log/httpd-access.log combined
    ErrorLog /home/docs/log/httpd-error.log
    <Directory /home/docs/public_html>
       Options Indexes FollowSymLinks
       AllowOverride all
    </Directory>
    <Directory /home/docs/public_html/cgi-bin>
       Options ExecCGI
       SetHandler cgi-script
    </Directory>
    </VirtualHost>

Create a directory where log files will be stored for this repository.

```
mkdir /home/docs/log
```

Activate the new configuration.

```
a2ensite docs
```

Restart the Web server.

```
service apache2 restart
```

3. Test the server by opening a browser window and visiting the page:

```
http://docs.simpledl.net/
```

If you get a Forbidden error, change the permissions on */home/docs* to 711 and/or the permissions on */home/docs/public_html* to 755.

### Step 3: Prepare Simple DL for offline management of repository

1. Install dependencies needed by Simple DL.  This is xsltproc, Imagemagick, unzip, pdftotext and some libraries needed by Perl.

```
sudo apt install imagemagick git unzip poppler-utils
sudo apt install libxml-libxslt-perl libxml-dom-perl libxml-dom-xpath-perl libtext-csv-perl
```

2. Edit data/users/1.email.xml to contain your Google account email.  This is a bootstrapping process for the admin account, and is mostly needed if you intend to use the Web interface but may also appear on some pages.

3. Edit the metadata in *data/spreadsheets* and collections in *public_html/collection* to change/add/delete collections and items.

Import metadata, configuration and other data into the site.

```
simpledl/bin/import.pl
```

Index your site for search and browse operations 

```
simpledl/bin/index.pl
```

Create HTML pages from the metadata XML, create thumbnails, etc.

```
simpledl/bin/generate.pl --all
```

4. Reload the page in your browser and you should see the updated archive.

### Step 4: Prepare Simple DL for online configuration

*Still being edited - Google changed authentication recently*

1. Set up Google authentication for the site.  This will require HTTPS for your server.

2. Test the login feature by clocking on login in the top-right corner.  You should be able to log into Google and then the login button will let you into the site.  Once logged in, there is an Admin link that give you the administrative interface where you can manage files and invoke the SimpleDL operations from the Web interface.


## How to configure the software

There are 4 directories:

* simpledl is the software and this should not normally need to be edited.
* data is where the configuration and source data are stored.
* public_html is the rendered website, along with scripts and digital objects (in collection). collection is the only directory that is not generated by the software.
* db is a space for temporary and extracted data, like the entity database and fulltext dumps.

Most configuration is done on the data directory, and this~docs/ gets used in generating the site.

* config/config.pl has the major configuration variables, including which
  fields get indexed for search/browse.  By default, this is set up for a subset of Dublin Core.
* config/transform.xsl converts metadata and website files from XML->HTML, so fundamental layout can be changed here.
* website is the specific template for this site.  Any files placed here will be copied across and XML generated into HTML.
* website/styles/style.css is the global CSS file.
* spreadsheets contains the CSV files used to generate the metadata.
* comments is where user comments are stored (this is disabled by default).
* uploads is where user uploads are stored (this is disabled by default).

Creating a new repository has 3 steps:

* running import.pl to create metadata in XML files from the spreadsheets
* running index.pl to index the metadata for search/browse
* running generate.pl to generate the website/HTML pages for metadata/thumbnails/etc.

Each command has options so you can run import.pl or generate.pl on parts of the data for greater efficiency.  By default, only metadata is imported or generated.  These commands also use a "--force" option to bypass the automatic determination of what needs to be reprocessed and simply process everything.  "--clean" will delete the directories so it makes a fresh copy (thereby avoiding old files lying around).

Hussein Suleman
24 June 2021
 
