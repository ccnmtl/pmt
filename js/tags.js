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
	     return $("#submitform input[name=iid]").val();
	 } else {
	     // get the nid from the reply form
	     return $("#replyform input[name=reply_to]").val();
	 }
}

function updateTags(data) {
	 log("updating tags");
	 $("#tagsave").val("save tags");

	 var newtags = map(function (t) {
		 return SPAN({},A({'href' : "/home.pl?mode=tag;tag=" + urlEncode(t.tag)}, t.tag)," ");
	 }, data);
	 $("#viewtags").html(newtags);
}

function saveFailed(err) {
	 alert("couldn't save tags: " + err);
}

function saveTags() {
	 var tags = $("#usertags").val();
	 var id = getId();
	 var idname = item_type == "item" ? "iid" : "nid";
	 var url = "/home.pl?mode=set_tags;" + idname + "=" + id + ";tags=" + urlEncode(tags);
	 var d = loadJSONDoc(url);
	 $("#tagsave").val('saving...');
	 d.addCallbacks(updateTags,saveFailed);
}


function initTagsForm() {
	 setItemType();
	 if (! $("#tagsave").length) return;
	 $("#tagsave").click(function () { saveTags(); return false; });
	 log("initialized tag form");
}

addLoadEvent(initTagsForm);