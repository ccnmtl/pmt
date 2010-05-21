var pulldowns = new Array();

var pulldownChange = function(number,value) {
  for(var i = number + 1; i < pulldowns.length; i++) {
      pulldowns[i].value = value;
    }

}

var setupPullDownHandlers = function () {
  var i = 0;
  forEach(getElementsByTagAndClassName("select","trackerprojectpulldown"),
    function (pulldown) {
      pulldowns.push(pulldown);
      var n = i;
      connect(pulldown,"onchange",function(e){pulldownChange(n,pulldown.value);});
      i++;
    });
};



addLoadEvent(setupPullDownHandlers);

