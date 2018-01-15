/**
 * Created by erikl on 2017-09-13.
 */
function footer_event() {
    if (Math.max(document.body.scrollHeight, document.body.offsetHeight) > window.innerHeight) {
        document.getElementById("footer").style.position = "relative";
    } else {
        document.getElementById("footer").style.position = "absolute";
    }
}

window.addEventListener("load",footer_event);
window.onresize = footer_event;

function initializeCountdown(endtime) {
    var clock = document.getElementById('time_to_next_meeting');
    var t = Date.parse(endtime + ':00:00 GMT+0100') - Date.parse(new Date().toString());
    var days = Math.floor(t / (1000 * 60 * 60 * 24));
    var hours = Math.floor((t / (1000 * 60 * 60)) % 24);
    var minutes = Math.floor((t / 1000 / 60) % 60);
    var seconds = Math.floor((t / 1000) % 60);
    if (t <= 0) {
        clock.innerHTML = "Mötet har startat!"
    } else {
        clock.innerHTML = 'Näste tilfälle om ' + days + ' dag(ar), ' +
            hours + ' timmar, ' +
            minutes + ' minuter och ' +
            seconds + " sekunder.";
        var timeinterval = setInterval(function () {
            var t = Date.parse(endtime + ':00:00 GMT+0100') - Date.parse(new Date().toString());
            var days = Math.floor(t / (1000 * 60 * 60 * 24));
            var hours = Math.floor((t / (1000 * 60 * 60)) % 24);
            var minutes = Math.floor((t / 1000 / 60) % 60);
            var seconds = Math.floor((t / 1000) % 60);
            if (t <= 0) {
                clearInterval(timeinterval);
                clock.innerHTML = "Mötet har startat!"
            } else {
                clock.innerHTML = 'Näste tilfälle om ' + days + ' dag(ar), ' +
                    hours + ' timmar, ' +
                    minutes + ' minuter och ' +
                    seconds + " sekunder.";
            }
        }, 1000);
    }
}

function newServerAjaxCall(url, data, onSuccess) {
    var request = new XMLHttpRequest();
    request.onreadystatechange = function() {
        if (this.readyState === 4) {
            if (this.status === 200) {
                onSuccess(this.responseText);
            } else {
                console.log("Error appeared for server ajax call: '" + url + "'");
                console.log(this.responseText);
            }
        }
    };
    request.open("POST", url, true);
    if (data === null) {
        request.send();
    } else {
        request.send(data);
    }
}


function open_user_menu() {
    var offsetWidth = document.getElementById("right_nav").offsetWidth;
    var menu = document.getElementById("user_menu");
    var posX = ((offsetWidth / 2) - (menu.offsetWidth / 2));
    if (posX > 0) {
        menu.style.right = posX.toString() + "px";
    } else {
        menu.style.right = "0px";
    }
    menu.style.visibility = "visible";
}

window.addEventListener("resize", function () {
    var menu = document.getElementById("user_menu");
    if(menu.style.visibility === "visible") {
        var posX = ((document.getElementById("right_nav").offsetWidth / 2) - (menu.offsetWidth / 2));
        if (posX > 0) {
            menu.style.right = posX.toString() + "px";
        } else {
            menu.style.right = "0px";
        }
    }
}, true);
window.addEventListener("click", function (e) {
    var menu = document.getElementById("user_menu");
    if(menu.style.visibility === "visible") {
        var x;
        var y;
        if (e.pageX || e.pageY) {
            x = e.pageX;
            y = e.pageY;
        }
        else {
            x = e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
            y = e.clientY + document.body.scrollTop + document.documentElement.scrollTop;
        }

        var minx = menu.offsetLeft;
        var maxx = menu.offsetLeft + menu.offsetWidth;
        var miny = menu.offsetTop + 38;
        var maxy = menu.offsetTop + menu.offsetHeight;

        if(!(x >= minx && x <= maxx && y >= miny && y <= maxy)) {
            menu.style.visibility = "hidden";
        }
    }
}, true);

function open_link(link) {
    var l = window.location.href;

    var pos = l.indexOf(link.substring(0, link.indexOf("=")));
    if(pos > 0) {
        var new_link = "";
        if(l.substr(pos).indexOf("&") > 0) {
            new_link = l.substr(0,pos) + l.substr(l.substr(pos).indexOf("&") + l.substring(0,pos).length + 1);
        } else {
            new_link = l.substring(0, pos - 1);
        }

        if(new_link.split("?").length - 1 >= 1) {
            window.open(new_link + "&" + link,"_self");
        } else {
            window.open(new_link + "?" + link,"_self");
        }
    } else {
        if(l.split("?").length - 1 >= 1) {
            window.open(l + "&" + link,"_self");
        } else {
            window.open(l + "?" + link,"_self");
        }
    }
}

function delete_item(loan_id,item_id, id, table_id) {
    var data = new FormData();
    data.append("loan_id", loan_id);
    data.append("item_id", item_id);
    data.append("quantity", 1);
    data.append("origin", 1);
    newServerAjaxCall("/remove-loan-item", data, function (response) {
        var obj = JSON.parse(response);
        console.log(response);
        if (obj.status === "true") {
            var row = document.getElementById("table_item_quantity_" + id);
            var antal = parseInt(row.innerText);
            if(antal > 1) {
                antal -= 1;
                row.innerHTML = "<p class=\"table_item\">" + antal + "</p>";
            } else {
                document.getElementById("table_row_" + id).parentNode.removeChild(document.getElementById("table_row_" + id));
                if(document.getElementById("table_id_" + table_id).rows.length <= 0) {
                    document.getElementById("table_id_" + table_id).parentNode.removeChild(document.getElementById("table_id_" + table_id));
                    document.getElementById("date_id_" + table_id).parentNode.removeChild(document.getElementById("date_id_" + table_id));
                }
            }
            console.log("Worked");
            footer_event();
        } else {
            console.log("Did not work!");
        }
    });
}
