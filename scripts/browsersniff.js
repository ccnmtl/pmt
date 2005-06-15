var uAgent = navigator.userAgent;
var aName = navigator.appName;
var aVendor = navigator.vendor;
var aVersion = parseInt(navigator.appVersion);

var macOS = (uAgent.indexOf('Mac') != -1 || uAgent.indexOf('mac') != -1);
var winOS = (uAgent.indexOf('Windows') != -1 || uAgent.indexOf('windows') != -1);

var Safaribrowser = (uAgent.indexOf('Safari') != - 1);
var IEbrowser = (uAgent.indexOf('MSIE') != - 1);
var Firefoxbrowser = (uAgent.indexOf("Firefox")!=-1);
var IEbrowser6 = (uAgent.indexOf("MSIE 6")!=-1);
