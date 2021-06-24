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

These instructions are to install Simple DL on a standard Ubuntu Linus variant, but they should easily be adaptable to other OSes as well.

1. Create a new Linux user account.  In this example the account is called *docs*.

```
sudo adduser docs
```

2. Either register a DNS name for your server or use a hosts entry to mimic this for a development machine.  Assuming the server's DNS name is docs.simpledl.net, you can set this in the hosts file by editing the first line as follows.

```
127.0.0.1       localhost docs.simpledl.net
```

3. Install Apache HTTPD server and suexec-custom set up so suexec works in home directories.  Suexec is a secure wrapper that Apache uses to execute applications as the user that owns the script.

```
sudo apt install apache2 apache2-suexec-custom
```
Configure suexec-custom by specifying the DocumentRoot for the server.  You can use */home* to keep all files in the home directory if this is not a widely-used production server.  If it is, it may be better to use */var/www* and then those selected users who are allowed to use Web applications can have directories within this.

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

Activate the new configuration.

```
a2ensite docs
```

Restart the Web server.

```
service apache2 restart
```

At this point you can test the server by opening a browser window and visiting the page:

```
http://docs.simpledl.net/~docs/
```

You should get a Forbidden error because the directory Apache is looking for does not exist.  This needs to be created and permissions granted for access to this.  Log in as the docs user.

```
mkdir /home/docs/public_html
```
git clone https://github.com/slumou/simpledl.git .

Reload the page in your browser and you should see an empty listing of files.  If you still get an error, change the permissions on */home/docs* to 711 and/or the permissions on */home/docs/public_html* to 755.

4. Install dependencies needed by Simple DL.  This is xsltproc, Imagemagick, unzip, and some libraries needed by Perl.

```
sudo apt install imagemagick git unzip
sudo apt install libxml-libxslt-perl libxml-dom-perl libxml-dom-xpath-perl libtext-csv-perl
```

5. In the user's home directory, create a directory named *simpledl* and change into this directory.

```
mkdir simpledl
cd simpledl
```

6. Obtain the source files from github by cloning the repository.

```
git clone https://github.com/slumou/simpledl.git .
```

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
 
