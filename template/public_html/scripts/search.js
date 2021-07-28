// In-browser javascript IR system with faceted search features
// Hussein Suleman
// 16 April 2019

// load an XML file locally or remotely
function loadXML (URL)
{
   var http_request = false;
   if (window.XMLHttpRequest) 
   { // Mozilla, Safari, ...
      http_request = new XMLHttpRequest();
      if (http_request.overrideMimeType) 
      {
         http_request.overrideMimeType('text/xml');
      }
   } 
   else if (window.ActiveXObject) 
   { // IE
      try {
         http_request = new ActiveXObject("Msxml2.XMLHTTP");
      } catch (e) {
         try {
            http_request = new ActiveXObject("Microsoft.XMLHTTP");
         } catch (e) {}
      }
   }

   if (!http_request) 
   {
      alert('Giving up :( Cannot create an XMLHTTP instance');
      return false;
   }

   // create and submit request
   http_request.open('GET', URL, false);
   try {
      http_request.send(null);
   }
   catch (e) {
      return null;
   }

   var XML = http_request.responseXML;
   if (XML && !XML.documentElement && http_request.responseStream) 
   {
      XML.load(http_request.responseStream);
   }
   
   return XML;
}


// persistent result storage for paging
var filenames = new Array ();
var ranked = new Array ();
var prefix = '';


// main search function
function doSearch (aprefix)
{
   var query;
   var terms;
//   var prefix;
   var index;
   var accum;
//   var filenames;
   var filetitles;

   // prefix for http requests
   if (toplevel == 'main')
      prefix = 'metadata/';
   else if (toplevel == 'users')
      prefix = 'users/';

   // split query into terms and split out spaces
   query = document.forms["searchform"].elements["searchbox"].value;
   query = query.toLowerCase ();
   query = query.replace (/['"_\.]/g, " ");
   query = query.replace (/^ +/, "");
   query = query.replace (/ +$/, "");
//   query = query.replace (/%20/, " ");
   
   // which index to use
   var use_index = document.forms["searchform"].elements["index"].value;
   if (! use_index)
      use_index = 1; 

   // turn extended unicode characters into simple numbers
   var i;
   var j = query.length;
   var newquery = '';
   for ( i=j-1; i>=0; i-- )
   {
      var achar = query.charAt (i);
      if (achar.match(/[a-zA-Z0-9\: ]/))
      {
         newquery = achar+newquery;
      }
      else
      {
         newquery = '_'+query.charCodeAt (i)+'_'+newquery;
      }
   }
   
   // create array
   accum = new Array();
//   filenames = new Array();
   filenames = new Array ();
   filetitles = new Array();

   // make sure we do not split an empty query   
   if (newquery == '')
      terms = new Array;
   else
      terms = newquery.split (/ +/);
   
   // read term frequency files
   for ( var i=0; i<terms.length; i++ )
   {
      var use_field = 'all';
      
      if (terms[i].match (/\:/))
      {
         var parts = terms[i].split (/\:/);
         if ((parts.length < 2) || (parts[0] == '') || (parts[1] == ''))
            continue;
         use_field = parts[0];
         terms[i] = parts[1];
      }
   
      index = loadXML ("indices/"+toplevel+"/search/"+use_index+"/"+use_field+"/_"+terms[i]+".xml");
      if (index == null)
         continue;

      var wordlist = index.getElementsByTagName ('tf');
      var df = wordlist.length;
      for ( var j=0; j<wordlist.length; j++ )
      {
         var value = wordlist.item(j).firstChild.data;
         var fileid = wordlist.item(j).getAttribute ('id');
         filenames[fileid] = wordlist.item(j).getAttribute ('file');
         filetitles[fileid] = wordlist.item(j).getAttribute ('title');
         if (isNaN (accum[fileid]))
            accum[fileid] = 0;
         accum[fileid] += parseFloat(value) / df;
      }
   }

   // selection sort based on weights, ignoring zero values
//   var ranked = new Array();
   ranked = new Array ();
   var weight = new Array();
   var k = 0;
   for ( var i=0; i<accum.length; i++ )
   {
      if (! isNaN (accum[i]))
      {
         ranked[k] = i;
         weight[k] = accum[i];
         k++;
      }
   }
   for ( var i=0; i<ranked.length; i++ )
   {
      var max = i;
      for ( var j=i+1; j<ranked.length; j++ )
         if (weight[j] > weight[max])
            max = j;
      if (max != i)
      {
         var swap = weight[i];
         weight[i] = weight[max];
         weight[max] = swap;
         swap = ranked[i];
         ranked[i] = ranked[max];
         ranked[max] = swap;
      }
   }

   // check for empty query and add full list of items
   if (query == '')
   {
      index = loadXML ("indices/"+toplevel+"/fulllist/index.xml");
      if (index)
      {
         var wordlist = index.getElementsByTagName ('tf');
         //var df = wordlist.length;
         for ( var j=0; j<wordlist.length; j++ )
         {
            var fileid = wordlist.item(j).getAttribute ('id');
            filenames[fileid] = wordlist.item(j).getAttribute ('file');
            filetitles[fileid] = wordlist.item(j).getAttribute ('title');
            ranked[j]=j;
            accum[fileid] = 1;
         }         
      }
   }

   // do browse and sort processing
   var config = loadXML ("config/config.xml");
   if (config)
   {
      // search for a matching index in the config file
      var toplevelconfig = null;
      var configs = config.getElementsByTagName ('toplevel');
      for ( var j=0; j<configs.length; j++ )
      {
         if (configs.item(j).getAttribute ('id') == toplevel)
            toplevelconfig = configs.item(j);
      }      
      if (toplevelconfig)
      {
         // check for browse filters and remove those results
         var bfields = toplevelconfig.getElementsByTagName ('field_browse').item(0).getElementsByTagName ('field');
         for ( var j=0; j<bfields.length; j++ )
         {
            var field_name = bfields.item(j).getElementsByTagName ('id').item(0).firstChild.data;
            var field_value = document.forms["searchform"].elements["field_browse_"+field_name].value;
            if (field_value != "all")
            {
               var browse_index = loadXML ("indices/"+toplevel+"/browse/1/"+field_name+"/"+field_value+".xml");
               if (browse_index)
               {
                  var ids = new Array ();
                  var bif = browse_index.getElementsByTagName ('bif');
                  for ( var k=0; k<bif.length; k++ )
                  {
                     ids[bif.item(k).getAttribute ('id')]=1;
                  }
                  var new_ranked = new Array ();
                  accum = new Array ();
                  var l=0;
                  for ( var k=0; k<ranked.length; k++ )
                     if (ids[ranked[k]] == 1)
                     {
                        new_ranked[l] = ranked[k];
                        accum[ranked[k]] = 1;
                        l++;
                     }
                  ranked = new_ranked;
               }
            }
         }
         // check for sort filters and apply
         var sort_value = document.forms["searchform"].elements["sort"].value;
         if (sort_value != 'relevance')
         {
            var sort_index = loadXML ("indices/"+toplevel+"/sort/"+sort_value+"/index.xml");
            if (sort_index)
            {
               var new_ranked = new Array ();
               var sif = sort_index.getElementsByTagName ('sif');
               for ( var j=0; j<sif.length; j++ )
               {
                  var fileid = sif.item(j).getAttribute ('id');
                  if ((! isNaN (accum[fileid])) && (accum[fileid] > 0))
                  {
                     new_ranked.push (fileid);
                  }
               }
               ranked = new_ranked;
            }
         }      
      }
   }
   
//   searchResults = ranked;

   document.forms["pager"].elements["pagenumber"].value = 1;
   document.getElementById ("numberofresults").innerHTML = ranked.length;
   displayPage();
}

function nextPage ()
{
   var pagenumber = parseInt (document.forms["pager"].elements["pagenumber"].value);
   var resultsperpage = parseInt (document.forms["pager"].elements["resultsperpage"].value);
   if (pagenumber*resultsperpage < ranked.length)
   {
      pagenumber++;
      document.forms["pager"].elements["pagenumber"].value = pagenumber;
      displayPage ();
   }
}

function prevPage ()
{
   var pagenumber = parseInt (document.forms["pager"].elements["pagenumber"].value);
   var resultsperpage = parseInt (document.forms["pager"].elements["resultsperpage"].value);
   if (pagenumber > 1)
   {
      pagenumber--;
      document.forms["pager"].elements["pagenumber"].value = pagenumber;
      displayPage ();
   }
}

function displayPage ()
{
   var pagenumber = parseInt (document.forms["pager"].elements["pagenumber"].value);
   var resultsperpage = parseInt (document.forms["pager"].elements["resultsperpage"].value);
   
   var resultsstart = document.getElementById ("resultsstart");
   var resultsend = document.getElementById ("resultsend");
   if (ranked.length > 0)
      resultsstart.innerHTML = ((pagenumber-1) * resultsperpage)+1;
   else
      resultsstart.innerHTML = '0';   
   if ((pagenumber*resultsperpage) < (ranked.length+1))
      resultsend.innerHTML = (pagenumber*resultsperpage);
   else
      resultsend.innerHTML = ranked.length;   

   // populate result list 
   var resultdiv = document.getElementById ("resultlist");
   var resultfrag = '';
   if (ranked.length > 0)
   {
//      resultfrag = '<ol>';
      for ( var i=(pagenumber-1) * resultsperpage; i<pagenumber*resultsperpage; i++ )
      if ((i>=0) && (i<ranked.length))
      {
         var fn = filenames[ranked[i]];
         fn = fn.replace (/\.xml/, ".html");
         
         // for Text output
//         resultfrag = resultfrag+'<li><b><a href="'+prefix+fn+'">'+filetitles[ranked[i]]+'</a></b><br/><i>'+filenames[ranked[i]]+'</i></li>';
//         resultfrag = resultfrag+'<li><b><a href="'+prefix+fn+'">'+filetitles[ranked[i]]+'</a></b></li>';
         
         // for output based on reading metadata files
         if (toplevel == 'users')
            resultfrag = resultfrag + renderUser (prefix, fn);
         else   
            resultfrag = resultfrag + renderMetadata (prefix, fn);
      }
//      resultfrag = resultfrag+'</ol>';
   }
   else
   {
      resultfrag = '<h2>No matches.</h2>';
   }
   resultdiv.innerHTML = resultfrag;
}

function renderMetadata (prefix, fn)
{
   var item = fn.replace (/\/index\.html$/, "");
   var metadataDocument = loadXML (prefix+item+'/metadata.xml');
   var itemfrag = '';
   
   if (! metadataDocument)
   {
      itemfrag = '<div class="searchthumb"><a href="'+prefix+fn+'"><div class="searchthumbtext"><p>'+item+'</p></div></a></div>';
   }
   else
   {
      itemfrag = '<div class="searchthumb"><a href="'+prefix+fn+'">';
      var itemfragcontent = '';
      // check for levelOfDescription that indicates a composite thumbnail
      var levelOfDescription = metadataDocument.getElementsByTagName ('item').item(0).getElementsByTagName('levelOfDescription');
      if (levelOfDescription.length > 0)
      {
         var LoD = levelOfDescription.item(0).firstChild.data;
         if (LoD == 'file')
         {
            itemfragcontent = itemfragcontent + '<div class="searchthumbimg"><img src="'+prefix+item+'/thumbnail.jpg"/></div>';
         }
         else
         {         
            var views = metadataDocument.getElementsByTagName ('item').item(0).getElementsByTagName('view');
            if (views.length > 0)
            {
               var files = views.item(0).getElementsByTagName ('file');
               if (files.length > 0)
               {
                  itemfragcontent = itemfragcontent + '<div class="searchthumbimg"><img src="thumbs/'+files.item(0).firstChild.data+'.jpg"/></div>';
               }
            }
         }
      }      
      // add in title if it exists
      var titles = metadataDocument.getElementsByTagName ('item').item(0).getElementsByTagName('title');
      if (titles.length > 0)
      {
         itemfragcontent = itemfragcontent + '<div class="searchthumbtext"><p>'+titles.item(0).firstChild.data+'</p></div>';
      }
      if (itemfragcontent == '')
      { itemfragcontent = '<div class="searchthumbtext"><p>'+item+'</p></div>'; }
      itemfrag = itemfrag + itemfragcontent + '</a></div>';         
   }
   return itemfrag;
}

function renderUser (prefix, fn)
{
   var item = fn.replace (/\.html$/, "");
   var metadataDocument = loadXML (prefix+item+'.xml');
   var itemfrag = '';
   
   if (! metadataDocument)
   {
      itemfrag = '<div class="searchuserthumb"><a href="'+prefix+fn+'"><div class="searchuserthumbtext"><p>'+item+'</p></div></a></div>';
   }
   else
   {
      itemfrag = '<div class="searchuserthumb"><a href="'+prefix+fn+'">';
      var itemfragcontent = '';
      // check for user name
      var names = metadataDocument.getElementsByTagName ('user').item(0).getElementsByTagName('name');
      if (names.length > 0)
      {
         var nameText = '(undefined name)';         
         if (names.item(0).hasChildNodes ())
         {
            nameText = names.item(0).firstChild.data;
         }
         itemfragcontent = itemfragcontent + '<div class="searchuserthumbtext"><p>'+nameText+'</p></div>';
      }
      if (itemfragcontent == '')
      { itemfragcontent = '<div class="searchuserthumbtext"><p>'+item+'</p></div>'; }
      itemfrag = itemfrag + itemfragcontent + '</a></div>';
   }
   return itemfrag;
}
 