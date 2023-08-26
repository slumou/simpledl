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


// check a list of strings for a matching regular expression
function regListSearch ( nextwords, termre )
{
   var found = 0;
   for ( var i=0; i<nextwords.length; i++ )
   {
      if (termre.test (nextwords[i]))
      { return true; }
   }
   return false;
}

// persistent result storage for paging
var filenames = new Array ();
var ranked = new Array ();
var prefix = '';
var query;

// main search function
function doSearch (aprefix)
{
   var terms;
   var index;

   // prefix for http requests
   if (toplevel == 'main')
      prefix = 'metadata/';
   else if (toplevel == 'users')
      prefix = 'users/';

   // split query into terms and split out spaces
   query = document.forms["searchform"].elements["searchbox"].value;
   query = query.toLowerCase ();
   query = query.replace (/['_\.]/g, " ");
   query = query.replace (/^ +/, "");
   query = query.replace (/ +$/, "");
   // query = query.replace (/%20/, " ");
   
   // which index to use
   var use_index = document.forms["searchform"].elements["index"].value;
   if (! use_index)
      use_index = 1; 

// debug use index 3!
//   use_index = 3;

   // create arrays
   var accum = new Array ();
   filenames = new Array ();
   var filetitles = new Array ();
   var phrases = new Array ();
   var requiredaccum = new Array ();
   var requiredaccumtemp = new Array ();
   var requiredTerms = 0;

   // first split into phrases
   var m;
   var re = /\+?\"[^\"]+\"|\+?[^\s\"]+/g;
   while (m = re.exec (query))
   {
      var phrase = m[0];
      phrase = phrase.replace (/(\+?)\"([^\"]+)\"/, "$1$2");
      phrases.push (phrase);
   }

   // iterate over all phrases
   for ( var k=0; k<phrases.length; k++ )
   {
      // console.log (phrases[k]);   
      
      // check for required indicator
      var required = 0;
      if (phrases[k].charAt(0) == "+")      
      {
         required = 1;
      }
      phrases[k] = phrases[k].replaceAll ("+", ""); // remove +s
      
      // create accum array for this phrase
      var paccum = new Array ();
   
      // read term frequency files for each term in each phrase
      var terms = phrases[k].split (/ +/);   
      for ( var i=terms.length-1; i>=0; i-- )
      {
         // info to track for trimming accums due to phrase searching
         var nextword = '';
         if (i+1 < terms.length)
         { nextword = terms[i+1]; }         
         var phraseaccum = new Array();
         
         // separate field from value
         var use_field = 'all';
         if (terms[i].match (/\:/))
         {
            var parts = terms[i].split (/\:/);
            if ((parts.length < 2) || (parts[0] == '') || (parts[1] == ''))
               continue;
            use_field = parts[0];
            terms[i] = parts[1];
         }
         
         // wildcards check
         var wildcards = 0;
         if ((terms[i].indexOf ("?") > -1) || (terms[i].indexOf ("*") > -1))
         { wildcards = 1; }
         var wildcardsnext = 0;
         if ((nextword.indexOf ("?") > -1) || (nextword.indexOf ("*") > -1))
         { wildcardsnext = 1; }         
         
         // process with full indexmap if there are wildcards
         var indexmap;
         var termre;
         if (wildcards == 1)
         {
            var termrestring = terms[i].replaceAll ("*", ".*");
            termrestring = termrestring.replaceAll ("?", ".");
            termre = new RegExp ("^"+termrestring+"$");
            indexmap = loadXML ("indices/"+toplevel+"/search/"+use_index+"/"+use_field+"/indexmap.xml");
            if (indexmap == null)
               continue;            
         }
         else // load in fast index map
         {
            indexmap = loadXML ("indices/"+toplevel+"/search/"+use_index+"/"+use_field+"/indexmapfast.xml");
            if (indexmap == null)
               continue;
         }
            
         // find the index within the indexmap
         var indexmapfilelist = indexmap.getElementsByTagName ('file');
         for (var l=0; l<indexmapfilelist.length; l++ )
         {
            var fileid = indexmapfilelist.item(l).getAttribute ('id');
            var allterms = indexmapfilelist.item(l).firstChild.data.split (/ +/);
            
            // if there are wildcards, find files that match
            if (wildcards == 1)
            {
               var found = 0;
               for ( var p=0; p<allterms.length; p++ )
               {
                  if (termre.test (allterms[p]))
                  { 
                     found = 1; 
                     break;
                  }
               }
               if (found == 0)
               { continue; } 
            }
            else // check if term appears within bounds of file
            {
               if (! ((terms[i].localeCompare (allterms[0]) >= 0) && (terms[i].localeCompare (allterms[allterms.length-1]) <= 0)))
               { continue; }
            }   
            
//console.log ('term '+terms[i]+' phrases '+phrases[k]);
            
            indexfile = loadXML ("indices/"+toplevel+"/search/"+use_index+"/"+use_field+"/index"+fileid+".xml");
            if (indexfile == null)
               continue;
            
            var index = indexfile.getElementsByTagName ('index');
            for ( var m=0; m<index.length; m++ )
            {
               // if the term is a match
               if (((wildcards == 0) && (index.item(m).getAttribute ("term") == terms[i])) ||
                   ((wildcards == 1) && (termre.test (index.item(m).getAttribute ("term")))))
               {
                  var wordlist = index.item(m).getElementsByTagName ('tf');
                  var df = wordlist.length;
                  for ( var j=0; j<wordlist.length; j++ )
                  {
                     var value = wordlist.item(j).firstChild.data;
                     var fileid = wordlist.item(j).getAttribute ('id');
                     var next = wordlist.item(j).getAttribute ('next');
                     if (terms.length > 1) // phrase search
                     {
                        if (i==(terms.length-1)) // the last term
                        {
                           if (isNaN (paccum[fileid]))
                              paccum[fileid] = 0;
                           paccum[fileid] += parseFloat(value) / df;
                           phraseaccum[fileid] = 0;
                        }
                        else // not the last term, so add weights but only for existing files
                        {
                           var nextwords = next.split (' ');
                           if (((wildcardsnext==0) && (nextwords.indexOf (nextword) > -1)) ||
                               ((wildcardsnext==1) && (regListSearch (nextwords, termre))))
                           {
                              if (! (isNaN (paccum[fileid])))
                              {
                                 paccum[fileid] += parseFloat(value) / df;
                                 phraseaccum[fileid] = 0;
                              }   
                           }
                        }   
                     }
                     else // non-phrase searches
                     {
                        if (isNaN (paccum[fileid]))
                           paccum[fileid] = 0;
                        paccum[fileid] += parseFloat(value) / df;
                     }   
                  }
               }
            }      
         }
         
         // remove accums for non-matches
         if (terms.length > 1)
         {
            for ( var n=0; n<paccum.length; n++ )
            {
               if ((! isNaN (paccum[n])) && (isNaN (phraseaccum[n])))
               {
                  paccum[n] = NaN; 
               }
            }
         }
      }
      
      // merge phrase accumulator into main accumulator or required accumulator
      if (required == 1)
      {
         if (requiredTerms == 0)
         { // move phrase accumulator into required accumulator
            requiredaccum = paccum;
         }
         else
         { // merge new required list into required accumulator
            for ( var i=0; i<requiredaccum.length; i++ )
            {
               if (! isNaN (requiredaccum[i]))
               {
                  if (! isNaN (paccum[i]))
                  { 
                     requiredaccum[i] += paccum[i]; 
                  }
                  else
                  {
                     requiredaccum[i] = NaN;
                  }
               }
            }
         }
         requiredTerms++;
      }
      else
      { // merge phrase accumulator into main accumulator
         for ( var i=0; i<paccum.length; i++ )
         {
            if (! isNaN (paccum[i]))
            {
               if (isNaN (accum[i]))
               { accum[i] = 0; }
               accum[i] += paccum[i];
            }   
         }
      }
   }   
   
   // merge required list and regular list
   if (requiredTerms > 0)
   {
      for ( var i=0; i<requiredaccum.length; i++ )
      {
         if ((! isNaN (requiredaccum[i])) && (! isNaN (accum[i])))
         {
            requiredaccum[i] += accum[i];
         }
      }
      accum=requiredaccum;
   }

   // selection sort based on weights, ignoring zero values
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

   // check for empty query and add full list of items, using existing ranked/accum if necessary
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
            if (query == '')
            {
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
      itemfrag = '<div class="searchthumb"><a href="'+prefix+fn+'?query='+query+'"><div class="searchthumbtext"><p>'+item+'</p></div></a></div>';
   }
   else
   {
      itemfrag = '<div class="searchthumb"><a href="'+prefix+fn+'?query='+query+'">';
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
      var titlesnippet = '';
      var titles = metadataDocument.getElementsByTagName ('item').item(0).getElementsByTagName('title');
      if (titles.length > 0)
      {
         titlesnippet = titles.item(0).firstChild.data;
      }   
      // add in identifier if it exists
      var identifiers = metadataDocument.getElementsByTagName ('item').item(0).getElementsByTagName('identifier');
      if (identifiers.length > 0)
      {
         titlesnippet = titlesnippet + ' ('+identifiers.item(0).firstChild.data+')';
      }
      if (titlesnippet != '')
      {  
         itemfragcontent = itemfragcontent + '<div class="searchthumbtext"><p>'+titlesnippet+'</p></div>';
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
 