/* 
 * (C) 2006 Daniel Schreiber <schreiber@esda.com>
 * This file may be distributed under the same license as Ruby on Rails.
 */
var oldoptions = new Object;
function prepareselect(id) {
	/* id => <select> element that should use typeahead search */
	var selectelement = document.getElementById(id);
	oldoptions[id] = selectelement.cloneNode(true);
	var span = document.createElement("span");
	selectelement.parentNode.insertBefore(span, selectelement);
	span.setAttribute("style", "border: 1px solid black; position: absolute; z-index: 1; background-color: white;");
	span.style.font = selectelement.style.font;
	var f = function(event) {
		editselect(event, id, span);
	};
	selectelement.onkeypress = f;
	selectelement.onblur = function (event) {
		span.style.zIndex = -1;
	};
	selectelement.onfocus = function (event) {
		span.style.zIndex = 1;
	};
}
function editselect(event, id, elem) {
	/* event -> Javascript Event,
	   id    -> <select> Element
	   elem  -> <span> Element, that show the input and holds state
	 */
	var key = event.which;
	var target = event.target;
	if (key >= 32 && key <= 128) {
		elem.innerHTML = elem.innerHTML + String.fromCharCode(key);
	} else if (key == 8) {
		elem.innerHTML = elem.innerHTML.slice(0, elem.innerHTML.length-1);
	}
	target.options.length=0;
	var r = new RegExp('^' + elem.innerHTML, 'i');
	for (i=0; i < oldoptions[id].options.length; i++) {
		if (oldoptions[id].options[i].text.search(r) != -1) {
			var o = new Option(oldoptions[id].options[i].text, oldoptions[id].options[i].value);
			target.options[target.options.length] = o;
		}
	}
	/* only 1 entry remaining => select it */
	if (target.options.length == 1 && 
	    target.options[0].text == elem.innerHTML) {
		target.options[0].selected = true;
		target.options[0].defaultSelected = true;
		target.value = target.options[0].value;
		target.selectIndex = 0;
	}
}

