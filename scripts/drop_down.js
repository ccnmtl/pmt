// JavaScript Document

var startList = function() {
    if (document.all&&document.getElementById) {
        var navRoot = $("nav");
	var lis = navRoot.getElementsByTagName("li");	
        for (var i=0; i<lis.length; i++) {
            var node = lis[i];
            node.onmouseover=function() {
     	        addElementClass(this,"over");
            }
            node.onmouseout=function() {
		removeElementClass(this,"over");
            }
        }
    }
}
addLoadEvent(startList);
