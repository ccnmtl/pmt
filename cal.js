var calvar  = "";
var formnum = 0;

function openCalWindow(startDate) {
    var scriptName;
    if(startDate != "") {
       scriptName = "http://pmt.ccnmtl.columbia.edu/cal.pl?start=" + startDate;
    } else {
       scriptName = "http://pmt.ccnmtl.columbia.edu/cal.pl";
    }
    window.open(scriptName,"calendarWindow",
    "toolbar=0,screenX=0,screenY=0,scrollbars=0,WIDTH=210,HEIGHT=170");
}

function getCalN(element,n) {
   calvar = element.name;
   formnum = n;
   openCalWindow(element.value);
}

function getCal(element) {
    getCalN(element,0);
}

function getCalNExternal (elementName,n) {
   calvar = elementName;
   formnum = n;
   var calval;
   eval("calval = document.forms[" + n + "]." + elementName + ".value");
   openCalWindow(calval);
}

function getCalExternal (elementName) {
   getCalNExternal(elementName,0);
}

