/* Based on aqtree3clickable from http://www.kryogenix.org/code/browser/aqlists/
Modifications by Jeremy Evans (code@jeremyevans.net) */

addEvent(window, "load", makeTreesC);

function makeTreesC() {
    if (!document.createElement) 
        return;
    uls = document.getElementsByTagName("ul");
    for (uli=0;uli<uls.length;uli++) {
        ul = uls[uli];
        if (ul.nodeName == "UL" && ul.className.split(" ").indexOf("scaffold_associations_tree") != -1) {
            processULELC(ul);
        }
    }
}

function processULELC(ul) {
    if (!ul.childNodes || ul.childNodes.length == 0) 
        return;
    for (var itemi=0;itemi<ul.childNodes.length;itemi++) {
        var item = ul.childNodes[itemi];
        if (item.nodeName == "LI") {
            var subul;
            subul = "";
            for (var sitemi=0;sitemi<item.childNodes.length;sitemi++) {
                if (item.childNodes[sitemi].nodeName == "UL") {
                    subul = item.childNodes[sitemi];
                    processULELC(subul);
                }
            }
            if (subul) {
                item.className = 'sat_closed'
                item.innerHTML = '<a href="#" class="treestatus" onclick=\'this.parentNode.className = (this.parentNode.className=="sat_open") ? "sat_closed" : "sat_open"; return false;\'></a>' + item.innerHTML
            } else {
                item.className = "sat_bullet";
                item.innerHTML = '<a href="#" class="treestatus" onclick=\'return false;\'></a>' + item.innerHTML
            }
        }
    }
}

/*              Utility functions                    */

function addEvent(obj, evType, fn){
    /* adds an eventListener for browsers which support it
       Written by Scott Andrew: nice one, Scott */
    if (obj.addEventListener){
        obj.addEventListener(evType, fn, false);
        return true;
    } else if (obj.attachEvent){
        var r = obj.attachEvent("on"+evType, fn);
        return r;
    } else {
        return false;
    }
}
