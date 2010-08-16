var item_type = "item";

function setItemType() {
	 var body = document.getElementsByTagName('body')[0];

	 if (body.id == "sectionforum") {
	    item_type = "node";
	    log("set item type to node");
	 } else {
	    log("item type is item");
	 }
}

function getId() {
	 if (item_type == "item") {
	 	 return $("submitform")['iid'].value;
         } else {
                 // get the nid from the reply form
	         return $("replyform")['reply_to'].value;
	 }
}

function updateTags(data) {
	 log("updating tags");
	 $("tagsave").value = "save tags";

	 var newtags = DIV({'id' : 'viewtags'},
	 map(function (t) {
	     return SPAN({},A({'href' : "/home.pl?mode=tag;tag=" +
	 urlEncode(t.tag)}, t.tag)," ");
	 }, data));

	 swapDOM($("viewtags"),newtags);
}

function saveFailed(err) {
	 alert("couldn't save tags: " + err);
}

function saveTags() {
	 var tags = $("usertags").value;
	 var id = getId();
	 var idname = item_type == "item" ? "iid" : "nid";
	 var url = "/home.pl?mode=set_tags;" + idname + "=" + id + ";tags=" + urlEncode(tags);
	 var d = loadJSONDoc(url);
	 var submit = $("tagsave");
	 submit.value = "saving...";
	 d.addCallbacks(updateTags,saveFailed);
}


function initTagsForm() {
	 setItemType();
	 var submit = $("tagsave");
	 if (!submit) return;
	 submit.onclick = function () { saveTags(); return false; }
	 log("initialized tag form");
}

addLoadEvent(initTagsForm);
