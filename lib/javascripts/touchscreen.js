//include.js :
// this is the only file necessary to call in pages using the ToolKit in the
// current version

/*******************************************************************************
 *
 * Baobab Touchscreen Toolkit
 *
 * A library for transforming HTML pages into touch-friendly user interfaces.
 *
 * (c) 2011 Baobab Health Trust (http://www.baobabhealth.org)
 *
 * For lincense details, see the README.md file
 *
 ******************************************************************************/

function __$(id){
    return document.getElementById(id);
}

function include(file){
    // Three links for the same file are also created to allow for usage of the calls in
    // pure HTML prototypes as well as RAILS application with 2 scenarios for pure
    // HTML prototypes in cases where sub-folders are used; a kind of overloading
    // due to javascript limitations as it can't check file existence
    var script1 = document.createElement("script");
    script1.setAttribute("language", "javascript");
    script1.setAttribute("src", "../javascripts/" + file + (!file.match(/\.js$/) ? ".js" : ""));
    script1.setAttribute("type", "text/javascript");

    document.getElementsByTagName("head")[0].appendChild(script1);

    var script2 = document.createElement("script");
    script2.setAttribute("language", "javascript");
    script2.setAttribute("src", "/javascripts/" + file + (!file.match(/\.js$/) ? ".js" : ""));
    script2.setAttribute("type", "text/javascript");

    document.getElementsByTagName("head")[0].appendChild(script2);

    var script3 = document.createElement("script");
    script3.setAttribute("language", "javascript");
    script3.setAttribute("src", "javascripts/" + file + (!file.match(/\.js$/) ? ".js" : ""));
    script3.setAttribute("type", "text/javascript");

    document.getElementsByTagName("head")[0].appendChild(script3);

    var fileType = file.match(/multiTouch|dashboard|standard/i);

    if(fileType){
        fileType = fileType[0];

        switch(fileType){
            case "multiTouch":
                includeCss("multiTouch");
                includeCss("dashboard");
                break;
            case "dashboard":
                includeCss("graytabs");
                includeCss("dashboard");
                includeCss("touch-fancy");
                break;
            default:
                includeCss("form");
                includeCss("graytabs");
                includeCss("touch-fancy");
                break;
        }
    }
}

// Three links for the same file are created to allow for usage of the method in
// pure HTML prototypes as well as RAILS application with 2 scenarios for pure
// HTML prototypes in cases where sub-folders are used; a kind of overloading
// due to javascript limitations as it can't check file existence
function includeCss(file){
    if(file != undefined){
        var link1 = document.createElement("link");
        link1.setAttribute("rel", "stylesheet");
        link1.setAttribute("href", "stylesheets/" + file + (!file.match(/\.css$/) ? ".css" : ""));
        link1.setAttribute("type", "text/css");

        document.getElementsByTagName("head")[0].appendChild(link1);

        var link2 = document.createElement("link");
        link2.setAttribute("rel", "stylesheet");
        link2.setAttribute("href", "/stylesheets/" + file + (!file.match(/\.css$/) ? ".css" : ""));
        link2.setAttribute("type", "text/css");

        document.getElementsByTagName("head")[0].appendChild(link2);

        var link3 = document.createElement("link");
        link3.setAttribute("rel", "stylesheet");
        link3.setAttribute("href", "../stylesheets/" + file + (!file.match(/\.css$/) ? ".css" : ""));
        link3.setAttribute("type", "text/css");

        document.getElementsByTagName("head")[0].appendChild(link3);
    }
}

function createLoadingMessage(){
    var msg = document.createElement("div");
    msg.id = "loadingProgressMessage";
    msg.style.zIndex = 1000;
    msg.style.color = "#00f";
    msg.style.backgroundColor = "#fff";
    msg.style.fontSize = "2em";
    msg.innerHTML = "<div id='progressAnimation' style='margin-top:35%; " +
    "font-style: italic; padding-left: 350px; border: 1px solid #fff; text-align: left;'>Loading. Please Wait...</div>";
    msg.style.position = "absolute";
    msg.style.left = "50%";
    msg.style.top = "50%";
    msg.style.width = "1000px";
    msg.style.height = "750px";
    msg.style.marginLeft = "-500px";
    msg.style.marginTop = "-380px";
    msg.style.textAlign = "center";
    msg.style.verticalAlign = "middle";

    document.body.appendChild(msg);

    setTimeout("changeProgressMessage('progressAnimation')", 300);
}

function changeProgressMessage(id){
    var obj = __$(id);

    if(obj){
        if(obj.innerHTML.trim() == "Loading. Please Wait..."){
            obj.innerHTML = "Loading. Please Wait";
        } else if(obj.innerHTML.trim() == "Loading. Please Wait"){
            obj.innerHTML = "Loading. Please Wait.";
        } else if(obj.innerHTML.trim() == "Loading. Please Wait."){
            obj.innerHTML = "Loading. Please Wait..";
        } else if(obj.innerHTML.trim() == "Loading. Please Wait.."){
            obj.innerHTML = "Loading. Please Wait...";
        }

        setTimeout("changeProgressMessage('" + id + "')", 300);
    }
}

// Load progress message
createLoadingMessage();

// Check the kind of page we have and render accordingly
// Added half a minute sleep to allow the page to finish loading.
if((document.forms[0] != undefined ? (document.forms[0].getAttribute("extended") != null ?
    (document.forms[0].getAttribute("extended") == "true" ? true : false) : false) : false)){

    include("multiTouch");
    setTimeout("initMultipleQuestions()", 200);


} else if(__$('home') != null || __$('dashboard') != null){

    include("dashboard");
    setTimeout("createPage()", 200);

} else {

    include("standard");
    setTimeout("loadTouchscreenToolkit()", 200);

<<<<<<< HEAD
=======
        // Make sure the next button is setup for right defaults
        nextButton.setAttribute("onMouseDown", "gotoNextPage()");
        // if in fast mode and not retrospective mode and missing is not disabled
        if (requireNextClick == "false") {
            if (tstRetrospectiveMode != "true"){
                nextButton.innerHTML=""
                nextButton.setAttribute("onMouseDown", "return false");
            }
            else if (missingDisabled != true){
                nextButton.innerHTML="<span>Skip</span>"
            }
        }

        // execute JS code when a field's page has just been loaded
        if (tstInputTarget.getAttribute("tt_onLoad")) {
            eval(tstInputTarget.getAttribute("tt_onLoad"));
        }

    }
    else{

        var popupBox = $("popupBox");
        if (popupBox) {
            popupBox.style.visibility = "visible";
        }

        document.forms[0].submit();
    }
}


function inputIsValid() {
    // don't leave current page if no value has been entered
    var ttInput = new TTInput(tstCurrentPage);
    var validateResult = ttInput.validate();
    var messageBar = $("messageBar");
    messageBar.innerHTML = "";

    if (validateResult.length > 0 && !tstSearchPage) {
        var message = validateResult;

        if (ttInput.shouldConfirm) {

            messageBar.innerHTML += "<p>" + ((message.match(/^Value\s/))?(message.replace(/^Value\s/, "The value <br /><b><i>" +
                ttInput.value + "</i></b><br /> is ")):message) + ".<br />Are you sure about this value?</p><div style='display: block;'><button class='button' style='float: left;' onclick='this.offsetParent.style.display=\"none\"; gotoPage(tstCurrentPage+1, false);' onmousedown='this.offsetParent.style.display=\"none\"; gotoPage(tstCurrentPage+1, false);'><span>Yes</span></button><button class='button' style='float: right; right: 3px;' onmousedown='this.offsetParent.style.display=\"none\"; '><span>No</span></button>";

            messageBar.style.display = "block";

        } else {
            showMessage(message)
        }
        return false;
    }
    return true;
}

function confirmValue() {
    var confirmationBar = $("confirmationBar");
    confirmationBar.innerHTML = "Username: ";
    var username = document.createElement("input");
    username.setAttribute("id", "confirmUsername");
    username.setAttribute("type", "text");
    username.setAttribute("textCase", "lower");
    confirmationBar.appendChild(username);

    confirmationBar.innerHTML += "<div style='display: block;'><input type='submit' value='OK' class='button' style='float: left;' onclick='validateConfirmUsername()' onmousedown='validateConfirmUsername()'/><input type='submit' value='Cancel' class='button' style='float: right; right: 3px;' onmousedown='cancelConfirmValue()' />";

    confirmationBar.style.display = "block";
    tstInputTarget = $("confirmUsername");
    if (typeof(barcodeFocusTimeoutId) != "undefined")
        window.clearTimeout(barcodeFocusTimeoutId);
    tstInputTarget.focus();
    tstKeyboard.innerHTML = "";

    if (!$("popupKeyboard")) {
        var popupKeyboard = document.createElement("div");
        popupKeyboard.setAttribute("id", "popupKeyboard");
        popupKeyboard.setAttribute("class", "keyboard");
        popupKeyboard.innerHTML = getPreferredKeyboard();
        contentContainer.appendChild(popupKeyboard);
    }
    $("backspace").style.display = "inline";
    hideMessage();
}

function validateConfirmUsername() {
    var username = $('confirmUsername');
    if (username.value == tstUsername) {
        cancelConfirmValue();
        gotoPage(tstCurrentPage+1, false);
    } else {
        showMessage("Username entered is invalid");
    }
}

function cancelConfirmValue() {
    $("confirmationBar").style.display = "none";
    tstInputTarget = $("touchscreenInput"+tstCurrentPage);
    if (typeof(focusForBarcodeInput) != "undefined")
        focusForBarcodeInput();

    contentContainer.removeChild($("popupKeyboard"));
    showBestKeyboard(tstCurrentPage);
}

function clearInput(){
    $('touchscreenInput'+tstCurrentPage).value = "";

    if(doListSuggestions){
        listSuggestions(tstCurrentPage);
    }
}

function showMessage(aMessage) {
    var messageBar = tstMessageBar;
    messageBar.innerHTML = aMessage;
    if (aMessage.length > 0) {
        messageBar.style.display = 'block'
        window.setTimeout("hideMessage()",3000)
    }
}

function hideMessage(){
    tstMessageBar.style.display = 'none'
}

function disableTouchscreenInterface(){
    // delete touchscreen tstPages
    contentContainer.removeChild($('page'+tstCurrentPage));
    contentContainer.removeChild($('keyboard'));
    contentContainer.removeChild($('progressArea'));
    contentContainer.removeChild($('buttons'));
    document.forms[0].style.display = 'block';

    touchscreenInterfaceEnabled = 0;
    document.getElementById('launchButton').innerHTML = "Enable Touchscreen UI";
}

function confirmCancelEntry(save) {     // If you want to save state set save =
    // true
    if (tstConfirmCancel) {
        tstMessageBar.innerHTML = "Are you sure you want to Cancel?<br/>" +
        "<button onmousedown='hideMessage(); cancelEntry();'><span>Yes</span></button>" +
        (save?"<button onmousedown='var completeField = document.createElement(\"input\"); \n\
				completeField.type = \"hidden\"; completeField.value = \"false\"; completeField.name = \"complete\"; \n\
				document.forms[0].appendChild(completeField); document.forms[0].submit(); hideMessage();'><span>Save</span></button>":"") +
        "<button onmousedown='hideMessage();'><span>No</span></button>";
        tstMessageBar.style.display = "block";
    } else {
        cancelEntry();
    }

}

function cancelEntry() {

    var inputElements = document.getElementsByTagName("input");
    for (i in inputElements) {
        inputElements[i].value = "";
    }

    window.location.href = window.tt_cancel_destination || "/people";       // "/patient/menu?no_auto_load_forms=true";/*
// specially
// for
// dmht
// */
}

//format the given element's value for display on the Progress Indicator
//TODO: Crop long values
function progressAreaFormat(anElement) {
    if (anElement.getAttribute("type") == "password") {
        return "****";
    } else {
        return anElement.value;
    }
}

function toggleShift() {
    tstShiftPressed = !tstShiftPressed;
}

function showBestKeyboard(aPageNum) {
    var inputElement = tstFormElements[tstPages[aPageNum]];
    if (isDateElement(inputElement)) {
        var thisDate = new RailsDate(inputElement);
        if (tstSearchPage) {
            if (thisDate.isDayOfMonthElement()) getDatePicker();
            else $("keyboard").innerHTML = getNumericKeyboard();
        }	else {
            getDatePicker();
        }
        return;
    }
    var optionCount = $('options').getElementsByTagName("li").length;
    if ((optionCount > 0 && optionCount < 6 && inputElement.tagName == "SELECT") || (inputElement.getAttribute("multiple") == "multiple")) {
        $("keyboard").innerHTML = "";
        return;
    }

    switch (inputElement.getAttribute("field_type")) {
        case "alpha":
            $("keyboard").innerHTML = getPreferredKeyboard();
            break;
        case "number":
            $("keyboard").innerHTML = getNumericKeyboard();
            break;
        case "date":
            getDatePicker();
            break;
        case "boolean":
            $("keyboard").innerHTML = "";
            break;
        default:
            $("keyboard").innerHTML = getPreferredKeyboard();
            break;
    }
}

//check if this element's name is for a Rails' datetime_select
function isDateElement(aElement) {
    if (aElement.getAttribute("field_type") == "date")
        return true;

    var thisRailsDate = new RailsDate(aElement);
    if (thisRailsDate.isYearElement())
        return true;

    if (thisRailsDate.isMonthElement())
        return true;

    if (thisRailsDate.isDayOfMonthElement())
        return true;

    return false;

/*
	 * // for date[year] dates if (aElement.name.search(/\[year\]/gi) != -1) return
	 * true;
	 * 
	 * if (aElement.id.search(/_day$/) != -1) return true;
	 *  // for person[date(1i)] dates var re = /([^\[]*)\[([^\(]*)\(([^\)]*)/ig; var
	 * str = re.exec(aElement.name); if (str == null) { str =
	 * re.exec(aElement.name); // i don't know why we need this! } if (str == null) {
	 * return false; } else { return true; } //return (str[2] != null);
	 */
}

//return whether this element represents a year, month or day of month
function getDatePart(aElementName) {
    var re = /[^\[]*\[([^\(]*)\(([^\)]*)/ig; // TODO What is this RE for?
    var str = re.exec(aElementName);
    if (str == null) {
        str = re.exec(aElementName); // i don't why we need this!
    }
    if (str != null) {
        return str[2];
    } else {
        return "";
    }
}



function gotoNextPage() {
    gotoPage(tstCurrentPage+1, true);
}

function	disableTextSelection() {
    if (navigator.userAgent.search(/opera/gi) != -1) {
        var theBody = contentContainer;
        theBody.onmousedown = disableSelect;
        theBody.onmousemove = disableSelect;
    }
}

function disableSelect(aElement)
{
    if (aElement && aElement.preventDefault)
        aElement.preventDefault();
    else if (window.event)
        window.event.returnValue = false;
}

function toggleMe(element){
    currentColor =  element.style.backgroundColor;
    if(currentColor == 'darkblue'){
        element.style.backgroundColor = "white";
        element.style.color = "black";
    }
    else{
        element.style.backgroundColor = "darkblue";
        element.style.color = "white";
    }
}

function addOption(optionText){
    document.getElementById('selections').innerHTML += "<div name='option' class='selectionOption' onMouseDown='toggleMe(this)'>"+optionText+"</div>";
}

function createKeyboardDiv(){
    var keyboard = $("keyboard");
    if (keyboard) keyboard.innerHTML = "";
    else {
        keyboard = document.createElement("div");
        keyboard.setAttribute('class','keyboard');
        keyboard.setAttribute('id','keyboard');
    }
    return keyboard;
}

function getQwertyKeyboard(){
    var keyboard;
    keyboard =
    "<span class='qwertyKeyboard'>" +
    "<span class='buttonLine'>" +
    getButtons("QWERTYUIOP") +
    getButtonString('backspace','Delete') +
    // getButtonString('date','Date') +
    "</span><span style='padding-left:15px' class='buttonLine'>" +
    getButtons("ASDFGHJKL") +
    getButtonString('apostrophe',"'");
		
    if(tstFormElements[tstCurrentPage].tagName == "TEXTAREA") {
        keyboard = keyboard +
        getButtonString('return',"ENTER");
    }

    keyboard = keyboard +
    "</span><span style='padding-left:25px' class='buttonLine'>" +
    getButtons("ZXCVBNM,.") +
    getButtonString('abc','A-Z') +
    getButtonString('num','0-9') +
    getButtonString('SHIFT','aA') +
    "</span>";

    if(tstFormElements[tstCurrentPage].tagName == "TEXTAREA") {
        keyboard = keyboard +
        "</span><span style='padding-left:93px' class='buttonLine'>" +
        getButtonString('whitespace','&nbsp', 'width: 520px;') +
        "</span>";
    }

    keyboard = keyboard +
    "</span>"
    return keyboard;
}

function getABCKeyboard(){
    // var keyboard = createKeyboardDiv();
    keyboard =
    "<span class='abcKeyboard'>" +
    "<span class='buttonLine'>" +
    getButtons("ABCDEFGH") +
    getButtonString('backspace','Delete') +
    getButtonString('num','0-9') +
    "</span><span class='buttonLine'>" +
    getButtons("IJKLMNOP") +
    getButtonString('apostrophe',"'") +
    getButtonString('SHIFT','aA') ;
		
    if(tstFormElements[tstCurrentPage].tagName == "TEXTAREA") {
        keyboard = keyboard +
        getButtonString('return',"ENTER");
    }

    keyboard = keyboard +
    getButtonString('Unknown','Unknown') +
    "</span><span class='buttonLine'>" +
    getButtons("QRSTUVWXYZ") +
    getButtonString('qwerty','qwerty') +
    "</span>";

    if(tstFormElements[tstCurrentPage].tagName == "TEXTAREA") {
        keyboard = keyboard +
        "</span><span style='padding-left:0px' class='buttonLine'>" +
        getButtonString('whitespace','&nbsp', 'width: 520px;') +
        "</span>";
    }

    keyboard = keyboard +
    "</span>";
    return keyboard;
}

function getNumericKeyboard(){
    var keyboard =
    "<span class='numericKeyboard'>" +
    "<span id='buttonLine1' class='buttonLine'>" +
    getButtons("123") +
    getCharButtonSetID("+","plus") +
    getCharButtonSetID("-","minus") +
    getCharButtonSetID("/","slash") +
    getCharButtonSetID("*","star") +
    getButtonString('char','A-Z') +
    getButtonString('date','Date') +
    "</span><span id='buttonLine2' class='buttonLine'>" +
    getButtons("456") +
    getCharButtonSetID("%","percent") +
    getCharButtonSetID("=","equals") +
    getCharButtonSetID("<","lessthan") +
    getCharButtonSetID(">","greaterthan") +
    getButtonString('qwerty','qwerty') +
    "</span><span id='buttonLine3' class='buttonLine'>" +
    getButtons("789") +
    getCharButtonSetID("0","zero") +
    getCharButtonSetID(".","decimal") +
    getCharButtonSetID(",","comma") +
    getButtonString('backspace','Delete') +
    getButtonString('Unknown','Unknown') +
    getButtonString('SHIFT','aA') +
    "</span>"
    return keyboard;
}

function getDatePicker() {
    if (typeof(DateSelector) == "undefined")
        return;

    var inputElement = tstFormElements[tstPages[tstCurrentPage]];
    var keyboardDiv = $('keyboard');
    keyboardDiv.innerHTML = "";

    var railsDate = new RailsDate(inputElement);
    if (railsDate.isDayOfMonthElement()) {
        getDayOfMonthPicker(railsDate.getYearElement().value, railsDate.getMonthElement().value);
        return;
    }

    var defaultDate = joinDateValues(inputElement);
    defaultDate = defaultDate.replace("-", "/", "g");
    var arrDate = defaultDate.split('/');
    $("touchscreenInput"+tstCurrentPage).value = defaultDate;

    if (!isNaN(Date.parse(defaultDate))) {
        ds = new DateSelector({
            element: keyboardDiv,
            target: tstInputTarget,
            year: arrDate[0],
            month: arrDate[1],
            date: arrDate[2],
            format: "dd/MM/yyyy"
        });
    } else {
        ds = new DateSelector({
            element: keyboardDiv,
            target: tstInputTarget,
            format: "dd/MMM/yyyy"
        });
    }

    $("options").innerHTML = "";
}

function getYearPicker() {
    ds = new DateSelector({
        element: $("keyboard"),
        target: tstInputTarget,
        format: "yyyy"
    });
}

function getMonthPicker() {
    ds = new DateSelector({
        element: $("keyboard"),
        target: tstInputTarget,
        format: "MM"
    });
}

function getDayOfMonthPicker(aYear, aMonth) {
    var keyboard =$('keyboard')
    keyboard.innerHTML = "";
    numberOfDays = DateUtil.getLastDate(aYear,aMonth-1).getDate();

    for(var i=1;i <= numberOfDays;i++){
        keyboard.innerHTML += getButtonString(i,i);

        /* set minimum width for the button to 80 pixels */
        button = document.getElementById(i);
        button.setAttribute("style","min-width:80px;");

        /* break on the seventh button, implying the end of the week */
        if(i%7 == 0) keyboard.innerHTML +="<span><br/></span>";
    }
    keyboard.innerHTML += getButtonString("Unknown","Unknown")

    if (tstInputTarget.value > numberOfDays) {
        tstInputTarget.value = numberOfDays;
    }
    tstInputTarget.setAttribute("singleButtonMode", "true");
/*
	 * if (aYear && aMonth) ds = new DateSelector({element: $("keyboard"), target:
	 * tstInputTarget, year: aYear, month: aMonth, format: "dd" }); else if (aMonth)
	 * ds = new DateSelector({element: $("keyboard"), target: tstInputTarget, month:
	 * aMonth, format: "dd" }); else ds = new DateSelector({element: $("keyboard"),
	 * target: tstInputTarget, format: "dd" });
	 */
}

function getButtons(chars){
    var buttonLine = "";
    for(var i=0; i<chars.length; i++){
        character = chars.substring(i,i+1)
        buttonLine += getCharButtonSetID(character,character)
    }
    return buttonLine;
}

function getCharButtonSetID(character,id){
    return '<button onMouseDown="press(\''+character+'\');" class="keyboardButton" id="'+id+'"><span>' +character+ '</span></button>';
}

function getButtonString(id,string){
    return "<button \
	onMouseDown='press(this.id);' \
	class='keyboardButton' \
	id='"+id+"'><span>"+
    string +
    "</span></button>";
}

function getButtonString(id, string, style){
    return "<button \
	onMouseDown='press(this.id);' \
	class='keyboardButton' \
	id='" + id + "' style='" + style + "'><span>" +
    string +
    "</span></button>";
}

function press(pressedChar){
    var now = new Date();
    var diff = tstLastPressTime && now.getTime() - tstLastPressTime.getTime();

    if (diff && diff < 80 ) {
        return;
    }

    inputTarget = tstInputTarget;
    var singleButtonMode = inputTarget.getAttribute("singleButtonMode");
    if (singleButtonMode)
        inputTarget.value = "";

    if (pressedChar.length == 1) {
        inputTarget.value += getRightCaseValue(pressedChar);

    } else {
        switch (pressedChar) {
            case 'backspace':
                inputTarget.value = inputTarget.value.substring(0,inputTarget.value.length-1);
                break;
            case 'done':
                touchScreenEditFinish(inputTarget);
                break;
            case 'space':
                inputTarget.value += ' ';
                break;
            case 'whitespace':
                inputTarget.value += ' ';
                break;
            case 'return':
                inputTarget.value += "\n";
                break;
            case 'apostrophe':
                inputTarget.value += "'";
                break;
            case 'abc':
                tstUserKeyboardPref = 'abc';
                $('keyboard').innerHTML = getPreferredKeyboard();
                if (typeof(saveUserKeyboardPref) != 'undefined'){
                    saveUserKeyboardPref('abc');
                }
                break;
            case 'qwerty':
                tstUserKeyboardPref = 'qwerty';
                $('keyboard').innerHTML = getPreferredKeyboard();
                if (typeof(saveUserKeyboardPref) != 'undefined'){
                    saveUserKeyboardPref('qwerty');
                }
                break;
            case 'num':
                $('keyboard').innerHTML = getNumericKeyboard();
                break;
            case 'char':
                $('keyboard').innerHTML = getPreferredKeyboard();
                if (typeof(saveUserKeyboardPref) != 'undefined'){
                    saveUserKeyboardPref('abc');
                }
                break;
            case 'date':
                getDatePicker();
                break;
            case 'SHIFT':
                toggleShift();
                break;
            case 'Unknown':
                inputTarget.value = "Unknown";
                break;

            default:
                if (tstShiftPressed) pressedChar = pressedChar.toUpperCase();
                inputTarget.value += pressedChar;
        }
    }

    if(doListSuggestions){
        listSuggestions(inputTargetPageNumber);
    }

    tstLastPressTime = new Date();
}

//ugly hack but it works!
//refresh options
function listSuggestions(inputTargetPageNumber) {
    if (inputTargetPageNumber == undefined) {
        return;
    }
    var inputElement = $('touchscreenInput'+inputTargetPageNumber);

    if(inputElement.getAttribute("ajaxURL") != null){
        ajaxRequest($('options'),inputElement.getAttribute("ajaxURL")+inputElement.value);
    }
    else{
        var optionsList = document.getElementById('options');
		var searchTerm = "";
        options = optionsList.getElementsByTagName("li");

 		if(inputElement.getAttribute("ttMatchFromBeginning") != null && inputElement.getAttribute("ttMatchFromBeginning") == "true"){
       		searchTerm = new RegExp("^" + inputElement.value,"i");
     	}else{
       		searchTerm = new RegExp(inputElement.value,"i");
     	}

        for(var i=0; i<options.length; i++){
            if(options[i].innerHTML.search(searchTerm) == -1){
                options[i].style.display = "none";
            }
            else{
                options[i].style.display = "block";
            }
        }
    }
}

//function matchOptions(stringToMatch){
function matchOptions(){
    stringToMatch = document.getElementById("inputContainer").innerHTML;
    options = document.getElementsByName('option');
    for(var i=0;i<options.length; i++){
        if(options[i].textContent.toLowerCase().indexOf(stringToMatch.toLowerCase()) == 0){
            document.getElementById("selections").style.top = -i * selectionHeight + "px";
            return;
        }
    }
}

function enableValidKeyboardButtons() {

    var inputElement = $('touchscreenInput'+inputTargetPageNumber);
    var patternStr = "(a-zA-Z0-9,.+()%])+";  // defualt validation pattern


    if (inputElement.getAttribute("validationRegexp")) {
        patternStr = inputElement.getAttribute("validationRegexp");
    };
    var availableKeys = "abcdefghijklmnopqrstuvwxyz0123456789.,;/%*+-";
    var validateUrl = "/cgi-bin/validate.cgi?p="+patternStr+"&keys="+availableKeys+"&s="+inputElement.value;

    httpRequest = new XMLHttpRequest();
    httpRequest.overrideMimeType('text/xml');
    httpRequest.onreadystatechange = function() {
        if (httpRequest.readyState == 4) {
            if (httpRequest.status == 200) {
                enableKeys(httpRequest.responseText, availableKeys);
            } else {
                // there was a problem with the request so we enable all keys
                enableKeys(availableKeys, availableKeys);
            }
        }
    };
    httpRequest.open('GET', validateUrl, true);
    httpRequest.send(null);
}

function enableKeys(validKeys, allKeys) {
    allKeys = allKeys.toUpperCase();
    validKeys = validKeys.toUpperCase();
    var keyButton;
    var keyboardElement = $("keyboard");
    // disable all keys
    for (var i=0;i<allKeys.length; i++) {
        if (keyButton = $(allKeys.substring(i,i+1))) {
            keyButton.style.backgroundColor = "";
            keyButton.style.color = "gray";
            keyButton.disabled = true;
        }
    }
    // enable only valid keys
    for (var i=0;i<validKeys.length; i++) {
        if (keyButton = $(validKeys.substring(i,i+1))) {
            keyButton.style.color = "black";
            keyButton.disabled = false;
        }
    }
}

function getRightCaseValue(aChar) {
    var newChar = '';
    var inputElement = tstInputTarget;
    var fieldCase = inputElement.getAttribute("textCase");

    switch (fieldCase) {
        case "lower":
            newChar = aChar.toLowerCase();
            break;
        case "upper":
            newChar = aChar.toUpperCase();
            break;
        case "mixed":
            if (tstShiftPressed)
                newChar = aChar.toUpperCase();
            else
                newChar = aChar.toLowerCase();
            break;
        default:		// Capitalise First Letter
            if (inputElement.value.length == 0 || tstShiftPressed)
                newChar = aChar.toUpperCase();
            else
                newChar = aChar.toLowerCase();
    }
    return newChar;
}

function stripLeadingZeroes(aNum) {
    var len = aNum.length;
    var newNum = aNum;
    while (newNum.substr(0,1) == '0') {
        newNum = newNum.substr(1,len-1)

    }
    return newNum;
}

function escape(s) {
    s = s.replace(">", "&gt;");
    s = s.replace("<", "&lt;");
    s = s.replace("\"", "&quot;");
    s = s.replace("'", "&apos;");
    s = s.replace("&", "&amp;");
    return s;
}

function unescape(s) {
    s = s.replace("&gt;", ">");
    s = s.replace("&lt;", "<");
    s = s.replace("&quot;", "\"");
    s = s.replace("&apos;", "'");
    s = s.replace("&amp;", "&");
    return s;
}

function checkKey(anEvent) {
    if (anEvent.keyCode == 13) {
        gotoNextPage();
        return;
    }
    if (anEvent.keyCode == 27) {
        confirmCancelEntry();
        return;
    }

    if(doListSuggestions){
        listSuggestions(inputTargetPageNumber);
    }

    tstLastPressTime = new Date();
}


function validateRule(aNumber) {
    var aRule = aNumber.getAttribute("validationRule")
    if (aRule==null) return ""

    var re = new RegExp(aRule)
    if (aNumber.value.search(re) ==-1){
        var aMsg= aNumber.getAttribute("validationMessage")
        if (aMsg ==null || aMsg=="")
            return "Please enter a valid value"
        else
            return aMsg
    }
    return ""
}


//Touchscreen Input element
var TTInput = function(aPageNum) {
    this.element = $("touchscreenInput"+aPageNum);
    this.formElement = tstFormElements[tstPages[aPageNum]]
    this.value = this.element.value;

    if (isDateElement(this.formElement)) {
        this.formElement.value = this.element.value; // update date value before
        // validation so we can use
        // RailsDate
        var rDate = new RailsDate(this.formElement);
        this.value = rDate.getDayOfMonthElement().value+"/"+rDate.getMonthElement().value+"/"+rDate.getYearElement().value;
    }
    this.shouldConfirm = false;
};
TTInput.prototype = {
    // return error msg when input value is invalid, blank otherwise
    validate: function() {
        var errorMsg = "";

        // validate existence
        errorMsg = this.validateExistence();
        if (errorMsg.length > 0) return errorMsg;

        if (this.value.length > 0 || !this.element.getAttribute('optional')){

            // validates using reg exp
            errorMsg = this.validateRule();
            if (errorMsg.length > 0) return errorMsg;

            // check validation code
            errorMsg = this.validateCode();
            if (errorMsg.length > 0) return errorMsg;

            // check ranges
            errorMsg = this.validateRange();
            if (errorMsg.length > 0) return errorMsg;

            // check existence in select options
            if (!isDateElement(this.formElement)) {
                errorMsg = this.validateSelectOptions();
                if (errorMsg.length > 0) return errorMsg;
            } else {
                var railsDate = new RailsDate(this.formElement);
                if (railsDate.isDayOfMonthElement()) {
                    errorMsg = this.validateSelectOptions();
                    if (errorMsg.length > 0) return errorMsg;
                }
            }
        }


        return "";
    },

    validateExistence: function() {
        // check for existence
        this.value = this.element.value
        if (this.value.length<1 && this.element.getAttribute("optional") == null) {
            return "You must enter a value to continue";
        }
        return "";
    },

    //
    validateRule: function() {
        return validateRule(this.element)
    },

    // validate using specified JS code
    validateCode: function() {
        var code = this.element.getAttribute('validationCode');
        var msg = this.element.getAttribute('validationMessage') || "Please enter a valid value";
        msg  += "<br> <a onmousedown='javascript:confirmValue()' href='javascript:;'>Authorise</a> </br>";

        if (!code || eval(code)) {
            return "";
        } else {
            return msg;
        }
    },

    validateRange: function() {
        var minValue = null;
        var maxValue = null;
        var absMinValue = null;
        var absMaxValue = null;
        var tooSmall = false;
        var tooBig = false;
        this.shouldConfirm = false;

        if (isDateElement(this.formElement)) {
            this.value.match(/(\d+)\/(\d+)\/(\d+)/);
            // var thisDate = new Date(this.value);
            var thisDate = new Date(RegExp.$3,parseFloat(RegExp.$2)-1, RegExp.$1);
            minValue = this.element.getAttribute("min");
            maxValue = this.element.getAttribute("max");
            absMinValue = this.element.getAttribute("absoluteMin");
            absMaxValue = this.element.getAttribute("absoluteMax");

            if (absMinValue) {
                absMinValue = absMinValue.replace(/-/g, '/');
                var minDate = new Date(absMinValue);
                if (minDate && (thisDate.valueOf() < minDate.valueOf())) {
                    tooSmall = true;
                    minValue = absMinValue;
                }
            }
            if (absMaxValue) {
                absMaxValue = absMaxValue.replace(/-/g, '/');
                var maxDate = new Date(absMaxValue);
                if (maxDate && (thisDate.valueOf() > maxDate.valueOf())) {
                    tooBig = true;
                    maxValue = absMaxValue;
                }
            }
            if (!tooSmall && !tooBig) {
                if (minValue) {
                    minValue = minValue.replace(/-/g, '/');
                    var minDate = new Date(minValue);
                    if (minDate && (thisDate.valueOf() < minDate.valueOf())) {
                        tooSmall = true;
                        this.shouldConfirm = true;
                    }
                }
                if (maxValue) {
                    maxValue = maxValue.replace(/-/g, '/');
                    var maxDate = new Date(maxValue);
                    if (maxDate && (thisDate.valueOf() > maxDate.valueOf())) {
                        tooBig = true;
                        this.shouldConfirm = true;
                    }
                }
            }

        } else if (this.element.getAttribute("field_type") == "number") {
            // this.value = this.getNumberFromString(this.value);
            var numValue = null;
            if (!isNaN(this.getNumberFromString(this.element.value)))
                numValue = this.getNumberFromString(this.element.value);
            else if (!isNaN(this.getNumberFromString(this.formElement.value)))
                numValue = this.getNumberFromString(this.formElement.value);
            else
                return "";


            minValue = this.getNumberFromString(this.element.getAttribute("min"));
            maxValue = this.getNumberFromString(this.element.getAttribute("max"));
            absMinValue = this.getNumberFromString(this.element.getAttribute("absoluteMin"));
            absMaxValue = this.getNumberFromString(this.element.getAttribute("absoluteMax"));

            if (!isNaN(numValue) && !isNaN(absMinValue)) {
                if (numValue < absMinValue) {
                    tooSmall = true;
                    minValue = absMinValue;
                }
            }
            if (!isNaN(numValue) && !isNaN(absMaxValue)) {
                if (numValue > absMaxValue) {
                    tooBig = true;
                    maxValue = absMaxValue;
                }
            }
            if (!tooBig && !tooSmall) {
                if (!isNaN(numValue) && !isNaN(minValue)) {
                    if (numValue < minValue) {
                        tooSmall = true;
                        this.shouldConfirm = true;
                    }
                }
                if (!isNaN(numValue) && !isNaN(maxValue)) {
                    if (numValue > maxValue) {
                        tooBig = true;
                        this.shouldConfirm = true;
                    }
                }
            }
        }

        if (tooSmall || tooBig) {
            if (!isNaN(minValue) && !isNaN(maxValue))
                return "Value out of Range: "+minValue+" - "+maxValue;
            if (tooSmall) return "Value smaller than minimum: "+ minValue;
            if (tooBig) return "Value bigger than maximum: "+ maxValue;
        }
        return "";
    },

    validateSelectOptions: function() {
        this.value = this.element.value
        var tagName = this.formElement.tagName;
        var suggestURL = this.formElement.getAttribute("ajaxURL") || "";
        var allowFreeText = this.formElement.getAttribute("allowFreeText") || "false";
        var optional = this.formElement.getAttribute("optional") || "false";

        if (tagName == "SELECT" || suggestURL != "" && allowFreeText != "true") {
            if (optional == "true" && this.value == "") {
                return "";
            }

            var isAValidEntry = false;

            var selectOptions = null;
            if (this.formElement.tagName == "SELECT") {
                selectOptions = this.formElement.getElementsByTagName("OPTION");
                var val_arr = new Array();
                var multiple = this.formElement.getAttribute("multiple") == "multiple";
                if (multiple)
                    val_arr = this.value.split(tstMultipleSplitChar);
                else
                    val_arr.push(this.value);
                isAValidEntry = true;
                for(var i=0; i<val_arr.length;i++){
                    if(!valueIncludedInOptions(val_arr[i], selectOptions)){
                        isAValidEntry = false;
                    }
                    break;
                }
            } else {
                selectOptions = $("options").getElementsByTagName("LI");
                for (var i=0; i<selectOptions.length; i++) {
                    if (selectOptions[i].value == this.value ||
                        selectOptions[i].text == this.value ||
                        selectOptions[i].innerHTML == this.value) {
                        isAValidEntry = true;
                        break;
                    }
                }
            }


            if (!isAValidEntry)
                return "Please select value from list (not: " + this.element.value + ")";

        }
        return "";
    },

    getNumberFromString: function(strValue) {
        var num = "";
        if (strValue != null && strValue.length > 0) {
            strValue.match(/(\d+\.*\d*)/);
            num = RegExp.$1;
        }
        return parseFloat(num);
    },
    /*
		 * The flag() function dispatches message flags from a TTInput object. To
		 * use it, add a 'JSON' flag in the options list of a given TTInput object.
		 * Syntax: 1. a string: :flag => '{"message":"This is a TTInput flag
		 * message", "condition":"expression"}' 2. Using Rails JSON Object :flag =>
		 * ({:message=>'This is a TTInput flag message', :condition =>
		 * 'expression'}).to_json
		 */
    flag: function(){
        var flag    = this.element.getAttribute("flag");
        if (flag){
            flag    = JSON.parse(flag);
            value   = (this.element.value || this.formElement.value);

            // return if the message, the condition and the value is missing
            if(!(flag['message'] && flag['condition'] && value)) return false;

            if (value.match(flag['condition'])){
                dispatchMessage(flag['message'], tstMessageBoxType.OKOnly);
                return true;
            }
        }
        return false;
    }

}



//Rails Date: object for parsing and manipulating Rails Dates
var RailsDate = function(aDateElement) {
    this.element = aDateElement;
};

RailsDate.prototype = {
    // return true if the anELement is stores day part of a date
    isDayOfMonthElement: function() {
        if (this.element.name.match(/\[day\]|3i|_day$/))
            return true;

        return false;
    },

    // return true if the anELement is stores month part of a date
    isMonthElement: function() {
        if (this.element.name.match(/\[month\]|2i/))
            return true;

        return false;
    },

    // return true if the anELement is stores year part of a date
    isYearElement: function() {
        if (this.element.name.match(/\[year\]|1i/))
            return true;

        return false;
    },

    // return the month element in the same set as anElement
    getDayOfMonthElement: function() {
        if (this.isDayOfMonthElement())
            return this.element;

        var dayElement = null;

        var re = /([^\[]*)\[([^\(]*)\(([^\)]*)/ig; // detect patient[birthdate(1i)]
        var str = re.exec(this.element.name);
        if (str == null) {
            str = re.exec(this.element.name); // i don't know why we need this!
        }
        if (str) {
            var strLen = str[1].length;
            var elementName = "";

            // check name_date[nameday(3i)]
            if ((str[1].search(/year$/) != -1) && (str[2].search(/year$/) != -1)) {
                str[1] = str[1].replace(/year$/, "date");
                str[2] = str[2].replace(/year$/, "day");
                elementName = str[1]+"["+str[2]+'(3i)]';
                dayElement = document.getElementsByName(elementName)[0];

            } else if ((str[1].search(/month$/) != -1) && (str[2].search(/month$/) != -1)) {
                str[1] = str[1].replace(/month$/, "date");
                str[2] = str[2].replace(/month$/, "day");
                elementName = str[1]+"["+str[2]+'(3i)]';
                dayElement = document.getElementsByName(elementName)[0];
            }

            if (!dayElement) {		// check name_date[name(3i)]
                if (str[1].search(/year$/) != -1 ) {
                    elementName = str[1].replace(/year$/, "date")+"["+str[2]+'(3i)]';
                    dayElement = document.getElementsByName(elementName)[0];
                } else if (str[1].search(/month$/) != -1 ) {
                    elementName = str[1].replace(/month$/, "date")+'['+str[2]+'(3i)]';
                    dayElement = document.getElementsByName(elementName)[0];
                }
            }

            if (!dayElement) {
                // patient[birthdate(1i)]
                if (this.isYearElement() &&
                    (this.element.name == str[1]+'['+str[2]+'(1i)]')) {
                    dayElement = document.getElementsByName(str[1]+'['+str[2]+'(3i)]')[0];

                } else if (this.isMonthElement() &&
                    (this.element.name == str[1]+'['+str[2]+'(2i)]')) {
                    dayElement = document.getElementsByName(str[1]+'['+str[2]+'(3i)]')[0];
                }
            }

        } else {
            // handle date[year], date[month], date[day]
            var nameLength = this.element.name.length;
            var elementName = "";

            if (this.element.name.search(/\[year\]/) != -1) {
                elementName = this.element.name.replace(/\[year\]/,"[day]");
                dayElement = document.getElementsByName(elementName)[0];

            } else if (this.element.name.search(/\[month\]/) != -1 ) {
                elementName = this.element.name.replace(/\[month\]/,"[day]");
                dayElement = document.getElementsByName(elementName)[0];
            }
        }
        // detect patient_year, patient_month, patient_day
        if (!dayElement && this.element.id.search(/_year$/)) {
            var elementId = this.element.id.replace(/_year$/, "_day");
            dayElement = $(elementId);

        } else if (!dayElement && this.element.id.search(/_month$/)) {
            var elementId = this.element.id.replace(/_month$/, "_day");
            dayElement = $(elementId);
        }

        return dayElement;
    },


    // return the month element in the same set as anElement
    getMonthElement: function() {
        if (this.isMonthElement()) return this.element;
        var monthElement = null;

        var re = /([^\[]*)\[([^\(]*)\(([^\)]*)/ig; // detect patient[birthdate(1i)]
        var str = re.exec(this.element.name);
        if (str == null) {
            str = re.exec(this.element.name); // i don't know why we need this!
        }
        if (str) {
            var strLen = str[1].length;
            var elementName = "";

            if (!monthElement) {		// name_month[namemonth(2i)]
                if ((str[1].search(/year$/) != -1) && (str[2].search(/year/) != -1)) {
                    str[1] = str[1].replace(/year$/, "month");
                    str[2] = str[2].replace(/year$/, "month");
                    elementName = str[1]+"["+str[2]+'(2i)]';
                    monthElement = document.getElementsByName(elementName)[0];

                } else if ((str[1].search(/date$/) != -1) && (str[2].search(/day$/) != -1)) {
                    str[1] = str[1].replace(/date$/, "month");
                    str[2] = str[2].replace(/day$/, "month");
                    elementName = str[1]+"["+str[2]+'(2i)]';
                    monthElement = document.getElementsByName(elementName)[0];
                }
            }

            if (!monthElement) {		// name_month[name(2i)]
                if (str[1].search(/year$/) != -1 ) {
                    elementName = str[1].replace(/year$/, "month")+'['+str[2]+'(2i)]';
                    monthElement = document.getElementsByName(elementName)[0];
                } else if (str[1].search(/date$/) != -1 ) {
                    elementName = str[1].replace(/date$/, "month")+'['+str[2]+'(2i)]';
                    monthElement = document.getElementsByName(elementName)[0];
                }
            }

            if (!monthElement) {		// name[name(2i)]
                if (this.isYearElement() &&
                    (this.element.name == str[1]+'['+str[2]+'(1i)]')) {
                    monthElement = document.getElementsByName(str[1]+'['+str[2]+'(2i)]')[0];

                } else if (this.isDayOfMonthElement() &&
                    (this.element.name == str[1]+'['+str[2]+'(3i)]')) {
                    monthElement = document.getElementsByName(str[1]+'['+str[2]+'(2i)]')[0];
                }
            }

        } else {
            // handle date[year], date[month], date[day]
            var nameLength = this.element.name.length;
            var elementName = "";

            if (this.element.name.search(/\[year\]/) != -1) {
                elementName = this.element.name.replace(/\[year\]/,"[month]");
                monthElement = document.getElementsByName(elementName)[0];

            } else if (this.element.name.search(/\[day\]/) != -1 ) {
                elementName = this.element.name.replace(/\[day\]/,"[month]");
                monthElement = document.getElementsByName(elementName)[0];
            }
        }
        // detect patient_day
        if (!monthElement && this.element.id.search(/_day$/)) {
            var elementId = this.element.id.replace(/_day$/, "_month");
            monthElement = $(elementId);
        }

        return monthElement;
    },

    // return the month element in the same set as anElement
    getYearElement: function() {
        if (this.isYearElement()) return this.element;
        var yearElement = null;

        var re = /([^\[]*)\[([^\(]*)\(([^\)]*)/ig; // detect patient[birthdate(1i)]
        var str = re.exec(this.element.name);
        if (str == null) {
            str = re.exec(this.element.name); // i don't know why we need this!
        }
        if (str) {
            var strLen = str[1].length;
            var elementName = "";

            if (!yearElement) {
                if ((str[1].search(/month$/) != -1) && (str[2].search(/month/) != -1)) {
                    str[1] = str[1].replace(/month$/, "year");
                    str[2] = str[2].replace(/month$/, "year");
                    elementName = str[1]+"["+str[2]+'(1i)]';

                } else if ((str[1].search(/date$/) != -1) && (str[2].search(/day$/) != -1)) {
                    str[1] = str[1].replace(/date$/, "year");
                    str[2] = str[2].replace(/day$/, "year");
                    elementName = str[1]+"["+str[2]+'(1i)]';
                }
                yearElement = document.getElementsByName(elementName)[0];
            }

            if (!yearElement) {
                if (str[1].search(/month$/) != -1 ) {
                    elementName = str[1].replace(/month$/, "year")+'['+str[2]+'(1i)]';
                } else if (str[1].search(/date$/) != -1 ) {
                    elementName = str[1].replace(/date$/, "year")+'['+str[2]+'(1i)]';
                }
                yearElement = document.getElementsByName(elementName)[0];
            }

            if (!yearElement) {
                yearElement = document.getElementsByName(str[1]+'['+str[2]+'(1i)]')[0];
            }

        } else {
            // handle date[year], date[month], date[day]
            var nameLength = this.element.name.length;
            var elementName = "";

            if (this.element.name.search(/\[month\]/) != -1) {
                elementName = this.element.name.replace(/\[month\]/,"[year]");
                yearElement = document.getElementsByName(elementName)[0];

            } else if (this.element.name.search(/\[day\]/) != -1 ) {
                elementName = this.element.name.replace(/\[day\]/,"[year]");
                yearElement = document.getElementsByName(elementName)[0];
            }
        }
        // detect patient_day
        if (!yearElement && this.element.id.search(/_day$/)) {
            var elementId = this.element.id.replace(/_day$/, "_year");
            yearElement = $(elementId);
        }

        return yearElement;
    },

    update: function(aValue) {
        if (this.isDayOfMonthElement()) {
            if (aValue.toLowerCase() == "unknown") {
                // this.element.value = "Unknown"
                this.element.value = aValue
            } else {
                this.element.value = stripLeadingZeroes(aValue);
            }
            return;
        }
        var dayElement = this.getDayOfMonthElement();
        var monthElement = this.getMonthElement();
        var yearElement = this.getYearElement();

        if (aValue.toLowerCase() == "unknown") {
            dayElement.value = "Unknown";
            monthElement.value = "Unknown";
            yearElement.value = "Unknown";
        }

        var dateArray = aValue.split('/');
        if (dayElement && !isNaN(dateArray[0])) {
            dayElement.value = stripLeadingZeroes(dateArray[0]);
        }

        if (monthElement && !isNaN(dateArray[1]))
            monthElement.value = stripLeadingZeroes(dateArray[1]);

        if (yearElement && !isNaN(dateArray[2]))
            yearElement.value = dateArray[2];

    }


};

//Add trim() method to String Class
String.prototype.trim = function()
{
    return this.replace(/^\s+|\s+$/g, '');
};

function getPreferredKeyboard(){
    if (typeof(tstUserKeyboardPref) != 'undefined' && tstUserKeyboardPref == 'qwerty') {
        return getQwertyKeyboard()
    }
    else{
        return getABCKeyboard()
    }
}

window.addEventListener("load", loadTouchscreenToolkit, false);

/*
 * The dispatchMessage(message, messageBoxType) displays a 'message' with a
 * custom message box The message box can be any of the types defined by
 * tstMessageBoxType i.e. tstMessageBoxType.OKOnly, tstMessageBoxType.OKCancel,
 * tstMessageBoxType.YesNo, tstMessageBoxType.YesNoCancel
 * 
 * By default, dispatchMessage(msg, messageBoxType) displays an OKCancel message
 * box if: a. the messageBoxType is not specified b. the messageBoxType
 * parameter does not match any of the message box types defined by
 * tstMessageBoxType
 */

function dispatchMessage(message, messageBoxType) {

    var buttons = "";

    /* if there is no message return false */
    if(!message) return false;

    switch(messageBoxType){
        case tstMessageBoxType.OKOnly:
            buttons = "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\"; gotoPage(tstCurrentPage+1, false);'> <span> OK </span> </button>"
            break;

        case tstMessageBoxType.OKCancel:
            buttons = "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\"; gotoPage(tstCurrentPage+1, false);'> <span> OK </span> </button>" +
            "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\";'> <span> Cancel </span> </button>"
            break;

        case tstMessageBoxType.YesNo:
            buttons = "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\"; gotoPage(tstCurrentPage+1, false);'> <span> Yes </span> </button>" +
            "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\";'> <span>No</span> </button>"
            break;

        case tstMessageBoxType.YesNoCancel:
            buttons = "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\"; gotoPage(tstCurrentPage+1, false);'> <span> Yes </span> </button>" +
            "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\";'> <span> No </span> </button>" +
            "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\";'> <span> Cancel </span> </button>"
            break;

        default:
            buttons = "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\"; gotoPage(tstCurrentPage+1, false);'> <span> OK </span> </button>" +
            "<button class = 'button' onclick = 'this.offsetParent.style.display=\"none\";'> <span> Cancel </span> </button>"
            break;

    }
    /* TODO: consider adding style = 'text-lign: left;' to the message div */
    message =  "<div  style = 'margin:20px;'>" + message + "</div>"
    tstMessageBar.innerHTML = message + buttons

    tstMessageBar.style.display = "block";

    return true;
}

/*
 * The dispatchFlag() function returns 'true' or 'false' depending on whether a
 * TTInput flag is raised on the current page.
 */
function dispatchFlag(){
    var thisPage = new TTInput(tstCurrentPage);

    return thisPage.flag();
}

function confirmRecordDeletion(message, form, container) {
    if(!tstMessageBar){
        var tstMessageBar = document.createElement("div");
        tstMessageBar.id  = "messageBar";
        tstMessageBar.className = "messageBar";

        tstMessageBar.innerHTML = message + "<br/>" +
        "<button onmousedown=\"document.getElementById('" + container + "').removeChild(document.getElementById('messageBar')); if(document.getElementById('" + form +
        "')) document.getElementById('" + form +
        "').submit();\"><span>Yes</span></button><button onmousedown=\"document.getElementById('" + container + "').removeChild(document.getElementById('messageBar'));\"><span>No</span></button>";

        tstMessageBar.style.display = "block";
        document.getElementById(container).appendChild(tstMessageBar);

        return false;
    }
    return false;
>>>>>>> 9658b742afd788769418a8c4e4943c1eb8460180
}
