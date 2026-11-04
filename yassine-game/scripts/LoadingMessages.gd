extends Node
## Title choices and last-visit memory; independent of the title's visuals.

const MESSAGES: PackedStringArray = [
	"for stimpy", "hello yassine", "大哥好",
	"السَّلَامُ عَلَيْكُمْ", "hiiiii 大哥", "herro, ya xine",
	"wagwan brotha", "what's up vro", "konichiwagwan mina slime",
	"Merhaba, yassine", "space gliding today?", "よぉ, stimpy",
	"hello bhstimpy", "annyeong, stimpy", "wassup, big bro"
]
const SAVE_PATH := "user://title_history.cfg"
const STORAGE_KEY := "yassine-game:last-title:v1"

var previous_message: String = ""
var persistence_available := true


func _ready() -> void:
	previous_message = _read_previous()


func choose_message() -> String:
	var choices: Array[String] = []
	for message in MESSAGES:
		if message != previous_message and not choices.has(message):
			choices.append(message)
	if choices.is_empty():
		push_error("Title pool needs at least two distinct greetings.")
		return previous_message
	previous_message = choices.pick_random()
	_save_previous(previous_message)
	return previous_message


func _read_previous() -> String:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem('" + STORAGE_KEY +
			"') || '';}catch(e){return null;}})()", true)
		persistence_available = value != null
		if not persistence_available:
			push_warning("Browser storage unavailable: title history lasts only this session.")
		return str(value) if value != null else ""
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		return str(config.get_value("title", "previous", ""))
	return ""


func _save_previous(message: String) -> void:
	if OS.has_feature("web"):
		# JSON encoding keeps quotes and multilingual text safe in JavaScript.
		var saved: Variant = JavaScriptBridge.eval(
			"(function(){try{localStorage.setItem('" + STORAGE_KEY + "'," +
			JSON.stringify(message) + ");return true;}catch(e){return false;}})()", true)
		persistence_available = saved == true
	else:
		var config := ConfigFile.new()
		config.set_value("title", "previous", message)
		persistence_available = config.save(SAVE_PATH) == OK
	if not persistence_available:
		push_warning("Could not save title history; reload non-repeat requires browser storage.")
