// Login and logout and other misc scripts
// Hussein Suleman
// 1 May 2019

var username = '';
var userID = '';
var moderation = '';
var administrator = '';

// all pages: to open the login popup window

function login1 (url)
{
   var w = 400;
   var h = 500;
   var leftPosition = (screen.width) ? (screen.width-w)/2 : 0;
   var topPosition = (screen.height) ? (screen.height-h)/2 : 0;
   var settings ='height='+h+',width='+w+',top='+topPosition+',left='+leftPosition+',scrollbars=no,resizable=no,location=no,menubar=no,titlebar=no,status=no,toolbar=no';
   var loginWindow = window.open(url,"Login",settings);
   return false;
}

// login page: for Google login processing

function renderLoginButton() {
   gapi.signin2.render('my-signin2', {
      'scope': 'profile email',
      'width': 200,
      'height': 40,
      'longtitle': true,
      'theme': 'dark',
      'onsuccess': onLoginSuccess,
      'onfailure': onLoginFailure
   });
}

function onLoginSuccess(googleUser) {
   var username = googleUser.getBasicProfile().getName();
   console.log('Logged in as: ' + username);
   var useremail = googleUser.getBasicProfile().getEmail();
   console.log('Email: ' + useremail);
   document.getElementById("loginbutton").setAttribute ('class', "login-button mdc-button mdc-button--raised");
   document.loginform.username.value = username;
   document.loginform.useremail.value = useremail;
   document.loginform.googlecookie.value = googleUser.getAuthResponse().id_token;
// set Google token in cookie for testing
//   document.cookie = "idtoken="+googleUser.getAuthResponse().id_token+"; path=/";
}

function onLoginFailure(error) {
   console.log(error);
}

// all pages: to do login checks and login interface updates

function getCookie(cname) {
  var name = cname + "=";
  var decodedCookie = decodeURIComponent(document.cookie);
  var ca = decodedCookie.split(';');
  for(var i = 0; i <ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length);
    }
  }
  return "";
}

function checkCookies () {
   username = getCookie ("username");
   if (username != "")
   {
      userID = getCookie ("userID");
      if (userID != "" )
      {
         moderation = getCookie ("moderation");
         administrator = getCookie ("admin");
         doLogin ();
      }
   }
}

function doLogin ()
{
   adminLink = "";
   if (administrator == "1")
   {
      adminLink = "| <a href=\"/cgi-bin/manage.pl\">Admin</a> "
   }
   document.getElementById ("login").innerHTML = "Logged in: "+username+" | <a href=\"/cgi-bin/editprofile.pl?userID="+userID+"\">Edit Profile</a> "+adminLink+"| <a href=\"#\" onClick=\"doLogout (); return false\">Logout</a>";
   if (document.getElementById("addcomment"))
      document.getElementById("addcomment").style.display = "block";
   if (document.getElementById("addcommentoff"))  
      document.getElementById("addcommentoff").style.display = "none";
   if (document.getElementById("addcommentformuser"))
      document.getElementById("addcommentformuser").value = username;
   if (document.getElementById("addcommentformuserID"))
      document.getElementById("addcommentformuserID").value = userID;
   if (document.getElementById("submitsection"))
      document.getElementById("submitsection").style.display = "block";
//   if (administrator == "1")
//   {
//      if (document.getElementById("managesection"))  
//         document.getElementById("managesection").style.display = "block";
//      if (document.getElementById ("outstanding") && (moderation!="0"))
//         document.getElementById ("outstanding").innerHTML = " [Requests outstanding: " + moderation + "]";
//   }      
}

function doLogout ()
{
   username = '';
   userID = '';
   document.cookie = "username="+''+"; path=/";
   document.cookie = "userID="+''+"; path=/";
   window.location.reload (false);
}

// any page with a search box: to jump to the search interface

function frontPageSearch ( avar ) 
{ 
   document.location.href="./search.html?query=" + avar;
}

// any page with a text box: to convert page breaks in text boxes into <br>s and make links live

function makeBreaks () {
   var i;
   for ( i=0; i<document.getElementsByClassName ("commentcontent").length; i++ )
   {
      document.getElementsByClassName ("commentcontent")[i].innerHTML =
      document.getElementsByClassName ("commentcontent")[i].innerHTML.replace
        (/\n/g,"<br/>");
   }
   for ( i=0; i<document.getElementsByClassName ("profilecontent").length; i++ )
   {
      document.getElementsByClassName ("profilecontent")[i].innerHTML =
      document.getElementsByClassName ("profilecontent")[i].innerHTML.replace
        (/\n/g,"<br/>");
   }
   for ( i=0; i<document.getElementsByTagName ("p").length; i++ )
   {
      document.getElementsByTagName ("p")[i].innerHTML =
      document.getElementsByTagName ("p")[i].innerHTML.replace
        (/\n/g,"<br/>");
      document.getElementsByTagName ("p")[i].innerHTML =
      document.getElementsByTagName ("p")[i].innerHTML.replace
        (/(https?:\/\/[^ <]+)/g,"<a href=\"$1\">$1</a>");  
   }
}

// management script: for management interface changes

function toggleExpand (pathNode) {
   if (document.getElementById(pathNode+'!a').innerHTML == '+') {
      document.getElementById(pathNode).style.display = 'block';
      document.getElementById(pathNode+'!a').innerHTML = ' -';
   } else {
      document.getElementById(pathNode).style.display = 'none';
      document.getElementById(pathNode+'!a').innerHTML = '+';
   };
}

function createFolder (path) {
   var folder = prompt ('Please enter the new folder name', '');
   if (folder != null)
   {
      document.manageform.path.value=path;
      document.manageform.action.value='createfolder';
      document.manageform.folder.value=folder;
      document.manageform.submit();
   }
   return false;
}

function updateUploads () {
   var state = 'none';
   if (document.manageform.uploadfile.value != '')
      state = 'inline';
   var elements = document.getElementsByClassName('uclass');
   for (var i = 0; i < elements.length; i++) {
      elements[i].style.display = state;
   }
}

function uploadFile (path) {
   document.manageform.path.value=path;
   document.manageform.action.value='uploadfile';
   document.manageform.submit();
   return false;
} 

function deleteFile (datasetpath, path) {

   var conf = confirm ('Are you sure you want to delete '+path.substring(2));
   if (conf == true)
   {
      document.manageform.path.value=datasetpath+path;
      document.manageform.action.value='deletefile';
      document.manageform.submit();
   }
   return false;
}

function downloadFile (datasetpath, path) {
   document.manageform.path.value=datasetpath+path;
   document.manageform.action.value='downloadfile';
   document.manageform.submit();
   return false;
}

// for front page carousel

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

function loadCarousel ()
{
  var d = document.getElementById ("indexcarousel");
  if (d)
  {
     var index = loadXML ("carousel/carousel.xml");
     if (index != null)
     {
        var imagelist = index.getElementsByTagName ('image');
        
        for ( var j=0; j<imagelist.length; j++ )
        {
           var src = imagelist.item(j).firstChild.data;
           var href = imagelist.item(j).getAttribute ('href');
           var title = imagelist.item(j).getAttribute ('title');
     
           var d2 = document.createElement ("div");
           var d3 = document.createElement ("a");
           d3.setAttribute ("href", href);
           var d4 = document.createElement ("img");
           d4.setAttribute ("src", "carousel/"+src);
           var d5 = document.createElement ("p");
           d5.setAttribute ("class", "slider-content");
           var d6 = document.createTextNode (title);
           d5.appendChild (d6);
           d3.appendChild (d4);
           d3.appendChild (d5);
           d2.appendChild (d3);
           d.appendChild (d2);
        }
     }
  }   
}  

// for metadata editing (comment and submission) pages

var numberOfFields = 0;
var numberOfReplicas = new Array ();
var config = null;
//if (config == null)
//   alert ('no config');

function makeNoteFragment (namei, description, wclass)
{
   return "<div class=\""+wclass+"\">"+
          description+
          "</div>";
}

function makeTextFragment (namei, description, wclass)
{
   return "<label class=\"mdc-text-field mdc-text-field--filled "+wclass+" textboxclass"+namei+"\">"+
          "<span class=\"mdc-text-field__ripple\"></span>"+
          "<input class=\"mdc-text-field__input\" id=\"cabox"+namei+"\" "+
          "name=\"mdfield"+namei+"\" type=\"text\" size=\"60\" "+
          "aria-labelledby=\"cabox"+namei+"\"/>"+
          "<span class=\"mdc-floating-label\" id=\"cabox"+namei+"\">"+
          description+"</span>"+
          "<span class=\"mdc-line-ripple\"></span>"+
          "</label>";
}

function makeAreaFragment (namei, description, wclass)
{
   return "<label class=\"mdc-text-field "+wclass+" mdc-text-field--textarea areaboxclass"+namei+"\">"+
          "<span class=\"mdc-text-field__ripple\"></span>"+
          "<textarea class=\"mdc-text-field__input\" rows=\"5\" cols=\"60\" aria-labelledby=\"cabox"+namei+"\" name=\"mdfield"+namei+"\"></textarea>"+
          "<span class=\"mdc-notched-outline\">"+
          "<span class=\"mdc-notched-outline__leading\"></span>"+
          "<span class=\"mdc-notched-outline__notch\">"+
          "<span class=\"mdc-floating-label\" id=\"cabox"+namei+"\">"+
          description+"</span>"+
          "</span>"+
          "<span class=\"mdc-notched-outline__trailing\"></span>"+
          "</span>"+
          "</label>";
}

function makeSelectFragment (namei, description, wclass, field)
{
   var frag = "<div class=\"mdc-select mdc-select--filled selectboxclass"+namei+" "+wclass+"\">"+
              "<div class=\"mdc-select__anchor\" role=\"button\" aria-haspopup=\"listbox\" aria-expanded=\"false\" aria-labelledby=\""+namei+"-label "+namei+"-selected-text\">"+
              "<input type=\"hidden\" name=\"mdfield"+namei+"\"/>"+
              "<span class=\"mdc-select__ripple\"></span>"+
              "<span id=\""+namei+"-label\" class=\"mdc-floating-label\">"+description+"</span>"+
              "<span class=\"mdc-select__selected-text-container\">"+
              "<span id=\""+namei+"-selected-text\" class=\"mdc-select__selected-text\"></span>"+
              "</span>"+
              "<span class=\"mdc-select__dropdown-icon\">"+
              "<svg class=\"mdc-select__dropdown-icon-graphic\" viewBox=\"7 10 10 5\" focusable=\"false\">"+
              "<polygon class=\"mdc-select__dropdown-icon-inactive\" stroke=\"none\" fill-rule=\"evenodd\" points=\"7 10 12 15 17 10\">"+
              "</polygon>"+
              "<polygon class=\"mdc-select__dropdown-icon-active\" stroke=\"none\" fill-rule=\"evenodd\" points=\"7 15 12 10 17 15\">"+
              "</polygon>"+
              "</svg>"+
              "</span>"+
              "<span class=\"mdc-line-ripple\"></span>"+
              "</div>"+
              "<div class=\"mdc-select__menu mdc-menu mdc-menu-surface mdc-menu-surface--fullwidth\">"+
              "<ul class=\"mdc-list\" role=\"listbox\" aria-label=\""+description+"\">"+
              "<li class=\"mdc-list-item mdc-list-item--selected\" aria-selected=\"true\" data-value=\"\" role=\"option\">"+
              "<span class=\"mdc-list-item__ripple\"></span>"+
              "</li>";

//              "<input type=\"hidden\" name=\"mdfield"+namei+"\" readonly class=\"mdc-select__selected-text\"/>"+
//              "<div class=\"mdc-select__anchor "+wclass+"\" role=\"button\" aria-haspopup=\"listbox\" aria-expanded=\"false\">"+
//              "<span class=\"mdc-select__ripple\"></span>"+
//              "<i class=\"mdc-select__dropdown-icon\"></i>"+
//              "<span class=\"mdc-floating-label mdc-floating-label--float-above\">"+description+"</span>"+
//              "<input type=\"text\" name=\"mdfield"+namei+"\" class=\"mdc-select__selected-text\"/>"+
//              "<i class=\"mdc-select__dropdown-icon\"></i>"+
//              "<span class=\"mdc-select__selected-text-container\">"+
//              "  <span id=\"demo-selected-text\" class=\"mdc-select__selected-text\"></span>"+
//              "</span>"+
              //"<span class=\"mdc-select__dropdown-icon\">"+
              //"<svg class=\"mdc-select__dropdown-icon-graphic\" viewBox=\"7 10 10 5\" focusable=\"false\">"+
              //"<polygon class=\"mdc-select__dropdown-icon-inactive\" stroke=\"none\" fill-rule=\"evenodd\" points=\"7 10 12 15 17 10\"></polygon>"+
              //"<polygon class=\"mdc-select__dropdown-icon-active\" stroke=\"none\" fill-rule=\"evenodd\" points=\"7 15 12 10 17 15\"></polygon>"+
              //"</svg></span>"+
//              "<div class=\"mdc-line-ripple\"></div>"+
//              "</div>"+
//              "<div class=\"mdc-select__menu mdc-menu mdc-menu-surface "+wclass+"\">"+
//              "<ul class=\"mdc-list\">"+
//              "<li class=\"mdc-list-item mdc-list-item--selected\" data-value=\"\" aria-selected=\"true\" role=\"option\">"+
//              "<span class=\"mdc-list-item__ripple\"></span>"+
//              "</li>";
         
   var options = field.getElementsByTagName ('option');
   for ( var i=0; i<options.length; i++ )
   {
      var option = options.item(i).firstChild.data;
      frag = frag + "<li class=\"mdc-list-item\" data-value=\""+option+"\" aria-selected=\"false\" role=\"option\">"+
                    "<span class=\"mdc-list-item__ripple\"></span>"+
                    "<span class=\"mdc-list-item__text\">"+option+"</span></li>";
   }                 
   return frag + "</ul></div></div>";
}

function makeFragment (field, i, fieldname, wclass)
{
   var name = field.getElementsByTagName ('name').item(0).firstChild.data;
   var type = field.getElementsByTagName ('type').item(0).firstChild.data;
   var description = field.getElementsByTagName ('description').item(0).innerHTML;
   if ((type == 'text') || (type == 'date'))
   {
      return makeTextFragment (fieldname+name+i, description, wclass);
   }
   else if (type == 'area')
   {
      return makeAreaFragment (fieldname+name+i, description, wclass);
   }
   else if (type == "select")
   {
      return makeSelectFragment (fieldname+name+i, description, wclass, field);
   }
   else if (type == "structured")
   {
      var fragments = '';
      var subfields = field.getElementsByTagName ('subfield');
      for ( var j=0; j<subfields.length; j++ )
      {
         fragments = fragments + "<div class=\"mdentrysubfield\">" + makeFragment (subfields.item(j), 1, name+i, 'mdentrysubfieldwidth') + "</div>";
      }
      return "<div class=\"mdentrysubfieldbox\">" + fragments + "</div>";
   }
   else if (type == "note")
   {
      return makeNoteFragment (fieldname+name+i, description, wclass);
   }
   return '';
}

function activate (field, i, fieldname)
{
   var name = field.getElementsByTagName ('name').item(0).firstChild.data;
   var type = field.getElementsByTagName ('type').item(0).firstChild.data;
   if ((type == 'text') || (type == 'date'))
   {
      mdc.textField.MDCTextField.attachTo(document.querySelector('.textboxclass'+fieldname+name+i));
   }
   else if (type == 'area')
   {
      mdc.textField.MDCTextField.attachTo(document.querySelector('.areaboxclass'+fieldname+name+i));
   }
   else if (type == 'select')
   {
      mdc.select.MDCSelect.attachTo(document.querySelector('.selectboxclass'+fieldname+name+i));
   }
   else if (type == 'structured')
   {
      var subfields = field.getElementsByTagName ('subfield');
      for ( var j=0; j<subfields.length; j++ )
      {
         activate (subfields.item(j), 1, name+i);
      }
   }
}

function add_field (num)
{
   numberOfReplicas[num]++;
   
   var fields = config.getElementsByTagName ('field');
   var optional = fields.item(num).getAttribute ('optional');
   var repeatable = fields.item(num).getAttribute ('repeatable');

   var fragment = makeFragment (fields.item(num), numberOfReplicas[num], '', 'mdentryfieldwidth');
   var form = "<div class=\"mdentryfieldbox\"><div class=\"mdentryfield\">" + fragment + "</div><div class=\"mdentryplus\"></div><div class=\"mdentryseparator\"></div></div>";

   var formcontents = document.getElementById ('replicas'+num);
   formcontents.insertAdjacentHTML ('beforeend', form);
   activate (fields.item(num), numberOfReplicas[num], '');
}

function createForm ()
{
   var fields = config.getElementsByTagName ('field');
   var form = '';
   for ( var i=0; i<fields.length; i++ )
   {
      var name = fields.item(i).getElementsByTagName ('name').item(0).firstChild.data;
      var type = fields.item(i).getElementsByTagName ('type').item(0).firstChild.data;
      var optional = fields.item(i).getAttribute ('optional');
      var repeatable = fields.item(i).getAttribute ('repeatable');
      
      numberOfFields++;
      numberOfReplicas[i] = 1;
      var fragment = makeFragment (fields.item(i), 1, '', 'mdentryfieldwidth');
      var optrep = '';
      if (optional == '0')
      {
         optrep = optrep + "<button id=\"opt"+name+"\" class=\"mdc-button opt-button"+name+"\" "+
                "onClick=\"return false\">"+
                "<div class=\"mdc-button__ripple\"></div>"+
                "<i class=\"material-icons mdc-icon-button__icon\">stars</i>"+
                "</button>";
      }
      if (repeatable == '1')
      {
         optrep = optrep + "<button id=\"add"+name+"\" class=\"mdc-button add-button"+name+"\" "+
                "onClick=\"add_field ("+i+"); return false\">"+
                "<div class=\"mdc-button__ripple\"></div>"+
                "<i class=\"material-icons mdc-icon-button__icon\">add_circle</i>"+
                "</button>";
      }
      
      var oneclass = 'mdentryfield';
//      if (type == 'structured')
//         oneclass = 'mdentrysubfield';
      form = form + "<div class=\"mdentryfieldbox\"><div class=\""+oneclass+"\">" + fragment + "</div><div class=\"mdentryplus\">" + optrep + '</div><div class=\"mdentryseparator\"></div></div>'+"<div id=\"replicas"+i+"\"></div>";
   }
   var formcontents = document.getElementById ('formcontents');
   formcontents.insertAdjacentHTML ('beforeend', form);
   for ( var i=0; i<fields.length; i++ )
   {
      var name = fields.item(i).getElementsByTagName ('name').item(0).firstChild.data;
      var type = fields.item(i).getElementsByTagName ('type').item(0).firstChild.data;
      var repeatable = fields.item(i).getAttribute ('repeatable');
      var optional = fields.item(i).getAttribute ('optional');
      
      activate (fields.item(i), '1', '');
      if (repeatable == '1')
      { 
         mdc.ripple.MDCRipple.attachTo(document.querySelector('.add-button'+name));
      }
      if (optional == '0')
      { 
         mdc.ripple.MDCRipple.attachTo(document.querySelector('.opt-button'+name));
      }
   }
//   alert (form.substring (3000));
}

function createMetadata ()
{
   var md = '';
   var root = config.getElementsByTagName ('root').item(0).firstChild.data;
   
   var fields = config.getElementsByTagName ('field');
   for ( var i=0; i<fields.length; i++ )
   {
      var name = fields.item(i).getElementsByTagName ('name').item(0).firstChild.data;
      var type = fields.item(i).getElementsByTagName ('type').item(0).firstChild.data;
      if ((type == 'date') || (type == 'text') || (type == 'area') || (type == 'select'))
      {
         for ( var j=1; j<=numberOfReplicas[i]; j++ )
         {
            var val = document.getElementById ('mdform').elements['mdfield'+name+j].value;
            if (val != "")
               md = md + "<" + name + ">" + val + "</" + name + ">\n";
         }
      }
      else if (type == 'structured')
      {
         for ( var j=1; j<=numberOfReplicas[i]; j++ )
         {
            var md2 = '';
            var subfields = fields.item(i).getElementsByTagName ('subfield');
            for ( var k=0; k<subfields.length; k++ )
            {
               var subname = subfields.item(k).getElementsByTagName ('name').item(0).firstChild.data;
               var subtype = subfields.item(k).getElementsByTagName ('type').item(0).firstChild.data;
               if ((subtype == 'date') || (subtype == 'text') || (subtype == 'area') || (subtype == 'select'))
               {
                  var val = document.getElementById ('mdform').elements['mdfield'+name+j+subname+'1'].value;
                  if (val != "")
                     md2 = md2 + "<" + subname + ">" + val + "</" + subname + ">\n";
               }
            }
            if (md2 != '')
               md = md + "<" + name + ">\n" + md2 + "</" + name + ">\n";
         }
      }
   }
   document.getElementById ('fullmetadata').value = "<" + root + ">\n" + md + "</" + root + ">\n";
}

// check if required fields are correct or other errors are present
function validateMetadata ()
{
   var fields = config.getElementsByTagName ('field');
   for ( var i=0; i<fields.length; i++ )
   {
      var name = fields.item(i).getElementsByTagName ('name').item(0).firstChild.data;
      var type = fields.item(i).getElementsByTagName ('type').item(0).firstChild.data;
      var optional = fields.item(i).getAttribute ('optional');
      if ((type == 'date') || (type == 'text') || (type == 'area') || (type == 'select'))
      {
         var found = 0;
         for ( var j=1; j<=numberOfReplicas[i]; j++ )
         {
            var val = document.getElementById ('mdform').elements['mdfield'+name+j].value;
            if (val != "")
            {
               found = 1;
               if (type == 'date')
               {
                  if (! /([0-9]{4})-(1[0-2]|0[1-9])-(3[01]|[0-2][1-9])(T(2[0-3]|[01][0-9]):([0-5][0-9]):([0-5][0-9]))?/.test (val))
                  {
                     var description = fields.item(i).getElementsByTagName ('description').item(0).firstChild.data;
                     alert ("Invalid date field\n"+name+"\n"+description);
                     return false;
                  }
               }
            }
         }
         if ((found == 0) && (optional == '0'))
         {
            var description = fields.item(i).getElementsByTagName ('description').item(0).firstChild.data;
            alert ("Missing value in required field\n"+name+"\n"+description);
            return false;
         }
      }
      else if (type == 'structured')
      {
         var found = 0;
         for ( var j=1; j<=numberOfReplicas[i]; j++ )
         {
            var subfields = fields.item(i).getElementsByTagName ('subfield');
            var foundInner = 0;
            for ( var k=0; k<subfields.length; k++ )
            {
               var subname = subfields.item(k).getElementsByTagName ('name').item(0).firstChild.data;
               var subtype = subfields.item(k).getElementsByTagName ('type').item(0).firstChild.data;
               if ((subtype == 'text') || (subtype == 'area') || (subtype == 'select'))
               {
                  var val = document.getElementById ('mdform').elements['mdfield'+name+j+subname+'1'].value;
                  if (val != "")
                     foundInner = 1;
               }
            }
            if (foundInner == 1)
               found = 1;
         }
         if ((found == 0) && (optional == '0'))
         {
            var description = fields.item(i).getElementsByTagName ('description').item(0).firstChild.data;
            alert ("Missing value in required field\n"+name+"\n"+description);
            return false;
         }
      }
   }
   return true;   
}

function validateContribution ()
{
   var comment = document.getElementById ('mdform').elements['commentbox'].value;
   if (value == '')
   {
      alert ('Missing text of contribution');
      return false;
   }   
   else
      return true;   
}

// validate, create MD and then return true to allow submitting of form
function submitMetadata ()
{
   var valid;
   if (caboxstatus == 0)
      valid = validateContribution ();
   else   
      valid = validateMetadata ();
   if (valid)
   {
      createMetadata ();
   }
   return valid;
}

var caboxstatus = 0;

function toggleAttachment ()
{
   if (caboxstatus == 1)
      document.getElementById('cabox').style = "display: none";
   else
      document.getElementById('cabox').style = "display: block";
   caboxstatus = 1-caboxstatus; 

   document.getElementById('addcomment-button').innerHTML = 'Submit Contribution and Attachment';
   document.getElementById('addcomment-button2').style = "display: none";
}

// user pages: to dynamically sort tables

function tableSort (table, column, asc)
{
   var tab = document.getElementById (table);
   var rows = tab.getElementsByTagName ("tr").length-1;
   var values = new Array ();   
   for ( var i=1; i<=rows; i++ )
   {
      var cell = tab.getElementsByTagName("tr").item(i);
      values[i-1] = {text:cell.getElementsByTagName("td").item(column).innerText, html:cell.innerHTML, position:i};
   }

   if (asc==1)
      values.sort ( function (a, b) { return a.text.localeCompare (b.text); } );
   else if (asc == 2)
      values.sort ( function (a, b) { return b.text.localeCompare (a.text); } );

   for ( var i=1; i<=rows; i++ )
   {
      tab.getElementsByTagName("tr").item(i).innerHTML=values[i-1].html;
   }   
}

// depot pages: to dynamically sort tables

function divSort (table, column, asc)
{
   var tab = document.getElementById (table);
   var rows = tab.children.length;
   var values = new Array ();
   for ( var i=0; i<rows; i++ )
   {
      var cell = tab.children.item(i);
      var spanValue = '';
      var spans = cell.getElementsByTagName ("span");
      if ((spans.length-1) >= column)
      { 
         spanValue = spans.item(column).innerText; 
      }
      values[i] = {text:spanValue, html:cell.innerHTML, position:i};
   }

   if (asc==1)
      values.sort ( function (a, b) { return a.text.localeCompare (b.text); } );
   else if (asc == 2)
      values.sort ( function (a, b) { return b.text.localeCompare (a.text); } );

   for ( var i=0; i<rows; i++ )
   {
      tab.children.item(i).innerHTML=values[i].html;
   }
}

