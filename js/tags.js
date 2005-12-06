function getIid() {
	 return $("submitform")['iid'].value;
}

function updateTags(data) {
	 log("updating tags");
	 $("tagsave").value = "save tags";

	 var newtags = DIV({'id' : 'viewtags'},
	 map(function (t) {
	     return SPAN({},A({'href' : "home.pl?mode=tag;tag=" +
	 urlEncode(t.tag)}, t.tag)," ");
	 }, data));

	 swapDOM($("viewtags"),newtags);
}

function saveFailed(err) {
	 alert("couldn't save tags: " + err);
}

function saveTags() {
	 var tags = $("usertags").value;
	 var iid = getIid();
	 var url = "home.pl?mode=set_tags;iid=" + iid + ";tags=" + urlEncode(tags);
	 var d = loadJSONDoc(url);
	 var submit = $("tagsave");
	 submit.value = "saving...";
	 d.addCallbacks(updateTags,saveFailed);
}


function initTagsForm() {
	 var submit = $("tagsave");
	 if (!submit) return;
	 submit.onclick = function () { saveTags(); return false; }
	 log("initialized tag form");
}

addLoadEvent(initTagsForm);
