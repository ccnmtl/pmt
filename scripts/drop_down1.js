// JavaScript Document

var nodes = [];
var hovering = 0; // set if the mouse is currently over an element

function domouseout(n) {
    if (hovering == 0) {
        rexp = /(\sover)+/;
        n.className = n.className.replace(rexp,"");
    }
}

startList = function() {
    if (document.all && document.getElementById) {
        navRoot = document.getElementById("nav");
        for (i=0; i<navRoot.childNodes.length; i++) {
            node = navRoot.childNodes[i];
            nodeID = i;
            if (node.nodeName=="LI") {
                node.onmouseover=function() {
                    this.className+=" over";
                    hovering = 1;    
                }
                node.onmouseout=function() {
                    nodes[nodeID] = this;
                    hovering = 0;
                    if (typeof TimerID != "undefined") clearTimeout(TimerID);
                    // this will not work:
                    // TimerID = setTimeout('this.className = this.className.replace(" over",""),1000);

                    // nor will this:
                    // n = this
                    // TimerID = setTimeout('n.className = n.className.replace(" over",""), 1000);

                    // in the end i have to do this:
                    TimerID = setTimeout('domouseout(nodes[nodeID])',500);
                     
                }
            }
        }
    }
}
window.onload=startList;
